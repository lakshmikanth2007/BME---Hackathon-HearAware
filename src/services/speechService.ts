import { SpeechTranscriptItem } from '../types/awareness';

interface SpeechRecognitionEvent {
  resultIndex: number;
  results: {
    length: number;
    [index: number]: {
      length: number;
      [index: number]: {
        transcript: string;
        confidence: number;
      };
      isFinal: boolean;
    };
  };
}

interface SpeechRecognitionInstance {
  continuous: boolean;
  interimResults: boolean;
  lang: string;
  start: () => void;
  stop: () => void;
  abort: () => void;
  onresult: ((event: SpeechRecognitionEvent) => void) | null;
  onerror: ((event: { error: string }) => void) | null;
  onend: (() => void) | null;
  onstart: (() => void) | null;
}

export type OnTranscriptCallback = (item: SpeechTranscriptItem, isInterim: boolean) => void;
export type OnNameCalledCallback = (
  callerPhrase: string,
  direction: 'left' | 'ahead' | 'right'
) => void;
export type OnVoiceCommandCallback = (command: {
  action: 'find' | 'describe' | 'stop' | 'help' | 'obstacles';
  target?: string;
  raw: string;
}) => void;
export type OnSpeechStatusCallback = (status: {
  listening: boolean;
  error?: string;
  supported: boolean;
}) => void;

export class SpeechService {
  private recognition: SpeechRecognitionInstance | null = null;
  private isListening = false;
  private isRecognizing = false;
  private currentProfile: 'blind' | 'deaf' = 'deaf';
  private targetUserName = 'Alex';
  private restartTimeout: ReturnType<typeof setTimeout> | null = null;

  private onTranscript: OnTranscriptCallback | null = null;
  private onNameCalled: OnNameCalledCallback | null = null;
  private onVoiceCommand: OnVoiceCommandCallback | null = null;
  private onSpeechStatus: OnSpeechStatusCallback | null = null;

  private synth: SpeechSynthesis | null = null;
  private lastSpokenText = '';
  private lastSpokenTime = 0;

  constructor() {
    if (typeof window !== 'undefined' && 'speechSynthesis' in window) {
      this.synth = window.speechSynthesis;
    }
  }

  public init(options: {
    profile: 'blind' | 'deaf';
    userName: string;
    onTranscript?: OnTranscriptCallback;
    onNameCalled?: OnNameCalledCallback;
    onVoiceCommand?: OnVoiceCommandCallback;
    onSpeechStatus?: OnSpeechStatusCallback;
  }): void {
    this.currentProfile = options.profile;
    this.targetUserName = options.userName.trim();
    this.onTranscript = options.onTranscript || null;
    this.onNameCalled = options.onNameCalled || null;
    this.onVoiceCommand = options.onVoiceCommand || null;
    this.onSpeechStatus = options.onSpeechStatus || null;

    this.setupRecognition();
  }

  public setUserName(name: string): void {
    this.targetUserName = name.trim();
  }

  public setProfile(profile: 'blind' | 'deaf'): void {
    this.currentProfile = profile;
  }

  private setupRecognition(): void {
    if (typeof window === 'undefined') return;

    const SpeechRec =
      (window as unknown as { SpeechRecognition?: new () => SpeechRecognitionInstance })
        .SpeechRecognition ||
      (window as unknown as { webkitSpeechRecognition?: new () => SpeechRecognitionInstance })
        .webkitSpeechRecognition;

    if (!SpeechRec) {
      this.onSpeechStatus?.({
        listening: false,
        supported: false,
        error: 'Web Speech API is not supported in this browser.',
      });
      return;
    }

    try {
      const rec = new SpeechRec();
      rec.continuous = true;
      rec.interimResults = true;
      rec.lang = 'en-US';

      rec.onstart = () => {
        this.isRecognizing = true;
        this.onSpeechStatus?.({ listening: true, supported: true });
      };

      rec.onresult = (e: SpeechRecognitionEvent) => {
        let interimText = '';
        let finalText = '';

        for (let i = e.resultIndex; i < e.results.length; ++i) {
          const trans = e.results[i][0].transcript;
          if (e.results[i].isFinal) {
            finalText += trans;
          } else {
            interimText += trans;
          }
        }

        const textToProcess = (finalText || interimText).trim();
        if (!textToProcess) return;

        this.processText(textToProcess, finalText.length > 0);
      };

      rec.onerror = (err) => {
        console.warn('Speech recognition status event:', err.error);
        if (err.error === 'not-allowed' || err.error === 'service-not-allowed') {
          this.onSpeechStatus?.({
            listening: false,
            supported: true,
            error: 'Speech permission restricted by browser. You can use Push-to-Talk or type below.',
          });
        }
      };

      rec.onend = () => {
        this.isRecognizing = false;
        // If we are supposed to be continuously listening, restart gracefully after a brief delay
        if (this.isListening) {
          if (this.restartTimeout) clearTimeout(this.restartTimeout);
          this.restartTimeout = setTimeout(() => {
            if (this.isListening && !this.isRecognizing) {
              try {
                rec.start();
              } catch {
                // Ignore if in transition
              }
            }
          }, 300);
        } else {
          this.onSpeechStatus?.({ listening: false, supported: true });
        }
      };

      this.recognition = rec;
      this.onSpeechStatus?.({ listening: false, supported: true });
    } catch (err) {
      console.warn('Speech recognition setup failed:', err);
    }
  }

  public processText(textToProcess: string, isFinal = true): void {
    // 1. Process for Deaf profile: Check if someone is calling the user's name
    if (this.targetUserName.length > 0) {
      const escapedName = this.targetUserName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const nameRegex = new RegExp(`\\b${escapedName}\\b`, 'i');
      if (nameRegex.test(textToProcess)) {
        let dir: 'left' | 'ahead' | 'right' = 'ahead';
        if (/left/i.test(textToProcess)) dir = 'left';
        else if (/right/i.test(textToProcess)) dir = 'right';

        if (this.onNameCalled) {
          this.onNameCalled(textToProcess, dir);
        }
      }
    }

    // 2. Process for Blind profile: Voice Commands
    if (this.currentProfile === 'blind') {
      this.parseVoiceCommand(textToProcess);
    }

    // 3. Emit transcript for live reading
    if (isFinal && this.onTranscript) {
      this.onTranscript(
        {
          id: `trans_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
          timestamp: new Date(),
          speaker: 'Speaker',
          text: textToProcess,
        },
        false
      );
    } else if (!isFinal && this.onTranscript) {
      this.onTranscript(
        {
          id: `interim_${Date.now()}`,
          timestamp: new Date(),
          speaker: 'Speaker',
          text: textToProcess,
        },
        true
      );
    }
  }

  private parseVoiceCommand(text: string): void {
    const lower = text.toLowerCase();

    // Find object command: e.g. "find bottle", "find my cup", "where is the chair", "look for keys"
    const findMatch = lower.match(
      /(?:find|where is|locate|look for|search for)\s+(?:a|an|the|my)?\s*([a-z\s]+)/i
    );
    if (findMatch && findMatch[1]) {
      const target = findMatch[1].trim().split(' ')[0];
      if (this.onVoiceCommand) {
        this.onVoiceCommand({
          action: 'find',
          target,
          raw: text,
        });
      }
      return;
    }

    if (/(?:stop|cancel|clear|stop searching)/i.test(lower)) {
      if (this.onVoiceCommand) {
        this.onVoiceCommand({ action: 'stop', raw: text });
      }
      return;
    }

    if (/(?:describe|what is in front|look around|scan)/i.test(lower)) {
      if (this.onVoiceCommand) {
        this.onVoiceCommand({ action: 'describe', raw: text });
      }
      return;
    }

    if (/(?:obstacle|danger|is anything ahead|what's ahead)/i.test(lower)) {
      if (this.onVoiceCommand) {
        this.onVoiceCommand({ action: 'obstacles', raw: text });
      }
      return;
    }

    if (/(?:help|commands|what can i say)/i.test(lower)) {
      if (this.onVoiceCommand) {
        this.onVoiceCommand({ action: 'help', raw: text });
      }
      return;
    }
  }

  public startListening(): void {
    this.isListening = true;
    if (this.recognition && !this.isRecognizing) {
      try {
        this.recognition.start();
      } catch {
        // Handled in onend
      }
    }
  }

  public stopListening(): void {
    this.isListening = false;
    if (this.restartTimeout) {
      clearTimeout(this.restartTimeout);
      this.restartTimeout = null;
    }
    if (this.recognition && this.isRecognizing) {
      try {
        this.recognition.stop();
      } catch {
        // ignore
      }
    }
    this.onSpeechStatus?.({ listening: false, supported: true });
  }

  // TTS Voice Output
  public speak(
    text: string,
    options?: { rate?: number; interrupt?: boolean; onEnd?: () => void }
  ): void {
    if (!this.synth) return;

    const now = Date.now();
    if (this.lastSpokenText === text && now - this.lastSpokenTime < 2500 && !options?.interrupt) {
      return;
    }
    this.lastSpokenText = text;
    this.lastSpokenTime = now;

    if (options?.interrupt) {
      this.synth.cancel();
    }

    const utterance = new SpeechSynthesisUtterance(text);
    utterance.rate = options?.rate ?? 1.0;
    utterance.pitch = 1.0;
    utterance.volume = 1.0;

    utterance.onend = () => options?.onEnd?.();
    utterance.onerror = () => options?.onEnd?.();

    this.synth.speak(utterance);
  }

  public stopSpeaking(): void {
    if (this.synth) {
      this.synth.cancel();
    }
  }
}

export const speechService = new SpeechService();
