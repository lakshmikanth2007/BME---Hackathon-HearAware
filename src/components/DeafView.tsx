import React, { useState } from 'react';
import {
  AlertTriangle,
  ArrowDown,
  ArrowLeft,
  ArrowRight,
  ArrowUp,
  Bell,
  Camera,
  CheckCircle,
  ChevronDown,
  ChevronUp,
  ExternalLink,
  Eye,
  HandMetal,
  HelpCircle,
  MessageSquare,
  Mic,
  Radio,
  Send,
  Trash2,
  UserCheck,
  Volume2,
  Zap,
} from 'lucide-react';
import { DetectedObject, SoundAlert, SpeechTranscriptItem } from '../types/awareness';
import { AudioVisualizer } from './AudioVisualizer';
import { CameraFeed } from './CameraFeed';

interface DeafViewProps {
  userName: string;
  transcripts: SpeechTranscriptItem[];
  interimTranscript: string;
  activeSoundAlert: SoundAlert | null;
  nameCallingAlert: { phrase: string; direction: 'left' | 'ahead' | 'right' } | null;
  onDismissSoundAlert: () => void;
  onDismissNameAlert: () => void;
  onClearTranscripts: () => void;
  onTriggerSimulatedSound: (type: 'doorbell' | 'horn' | 'blast' | 'knock' | 'name') => void;
  onDirectSpeechInput: (text: string) => void;
  micActive: boolean;
  micVolume: number;
  frequencyBands: number[];
  micDeviceLabel?: string;
  speechError?: string;
  isIframeBlocked?: boolean;
  // Camera props for deaf view visibility
  cameraStream: MediaStream | null;
  cameraActive: boolean;
  cameraError?: string;
  cameraLabel?: string;
  detectedObjects: DetectedObject[];
  videoElementRef: React.RefObject<HTMLVideoElement>;
  onRetryCamera: () => void;
  onImageUploaded?: (img: HTMLImageElement) => void;
}

export const DeafView: React.FC<DeafViewProps> = ({
  userName,
  transcripts,
  interimTranscript,
  activeSoundAlert,
  nameCallingAlert,
  onDismissSoundAlert,
  onDismissNameAlert,
  onClearTranscripts,
  onTriggerSimulatedSound,
  onDirectSpeechInput,
  micActive,
  micVolume,
  frequencyBands,
  micDeviceLabel,
  speechError,
  isIframeBlocked,
  cameraStream,
  cameraActive,
  cameraError,
  cameraLabel,
  detectedObjects,
  videoElementRef,
  onRetryCamera,
  onImageUploaded,
}) => {
  const [typedText, setTypedText] = useState('');
  const [showSimulators, setShowSimulators] = useState(false);
  const [showCamera, setShowCamera] = useState(false);

  // Auto-dismiss sound alert after 7 seconds to prevent alert clutter
  React.useEffect(() => {
    if (activeSoundAlert) {
      const timer = setTimeout(() => {
        onDismissSoundAlert();
      }, 7000);
      return () => clearTimeout(timer);
    }
  }, [activeSoundAlert, onDismissSoundAlert]);

  // Auto-dismiss name calling alert after 8 seconds
  React.useEffect(() => {
    if (nameCallingAlert) {
      const timer = setTimeout(() => {
        onDismissNameAlert();
      }, 8000);
      return () => clearTimeout(timer);
    }
  }, [nameCallingAlert, onDismissNameAlert]);

  const handleSendText = (e: React.FormEvent) => {
    e.preventDefault();
    if (!typedText.trim()) return;
    onDirectSpeechInput(typedText.trim());
    setTypedText('');
  };

  const getDirectionVisual = (direction: string) => {
    switch (direction) {
      case 'left':
        return { label: 'ON YOUR LEFT', icon: <ArrowLeft className="w-5 h-5 text-white" /> };
      case 'right':
        return { label: 'ON YOUR RIGHT', icon: <ArrowRight className="w-5 h-5 text-white" /> };
      case 'behind':
        return { label: 'BEHIND YOU', icon: <ArrowDown className="w-5 h-5 text-white" /> };
      default:
        return { label: 'DIRECTLY AHEAD', icon: <ArrowUp className="w-5 h-5 text-white" /> };
    }
  };

  return (
    <div className="flex flex-col gap-4 w-full">
      {/* 0. IFRAME PERMISSION NOTICE */}
      {isIframeBlocked && (
        <div className="p-4 rounded-3xl bg-[#2A1800] border-2 border-[#FFD60A] text-white flex flex-col sm:flex-row items-center justify-between gap-3 shadow-xl">
          <div className="flex items-center gap-3">
            <AlertTriangle className="w-7 h-7 text-[#FFD60A] flex-shrink-0" />
            <div className="text-sm">
              <p className="font-bold text-[#FFD60A]">Camera/Mic Blocked in Embedded Frame</p>
              <p className="text-neutral-300 text-xs mt-0.5">
                Some browsers restrict permissions in embedded frames. Open direct tab for full access.
              </p>
            </div>
          </div>
          <a
            href={window.location.href}
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-[#FFD60A] text-black font-black text-xs uppercase tracking-wider hover:bg-[#e6c008] transition-all flex-shrink-0 shadow-md"
          >
            <span>Open Full Tab</span>
            <ExternalLink className="w-4 h-4" />
          </a>
        </div>
      )}

      {/* 1. URGENT ALERT POPUP: "SOMEONE IS CALLING YOU" */}
      {nameCallingAlert && (
        <div
          role="alert"
          aria-live="assertive"
          className="p-5 rounded-3xl bg-[#6E0010] border-4 border-white text-white shadow-2xl animate-pulse flex flex-col items-center text-center gap-3"
        >
          <div className="flex items-center gap-2 px-4 py-1.5 rounded-full bg-white text-black font-black text-sm uppercase tracking-wider">
            <UserCheck className="w-5 h-5 text-red-600" />
            <span>NAME CALLED ALERT</span>
          </div>

          <h2 className="text-3xl md:text-4xl font-black tracking-wide uppercase">
            SOMEONE IS CALLING YOU!
          </h2>

          <div className="flex items-center gap-2 px-5 py-2.5 rounded-2xl bg-black/70 border-2 border-[#FFD60A]">
            {getDirectionVisual(nameCallingAlert.direction).icon}
            <span className="text-xl md:text-2xl font-black text-[#FFD60A] tracking-wider">
              {getDirectionVisual(nameCallingAlert.direction).label}
            </span>
          </div>

          <p className="text-lg md:text-xl font-bold italic bg-black/40 px-4 py-2 rounded-xl border border-white/30 max-w-full">
            "{nameCallingAlert.phrase}"
          </p>

          <button
            type="button"
            onClick={onDismissNameAlert}
            className="w-full mt-2 py-3.5 rounded-2xl bg-[#FFD60A] hover:bg-[#e6c008] text-black font-black text-lg uppercase tracking-wider transition-all cursor-pointer shadow-lg"
          >
            ACKNOWLEDGE
          </button>
        </div>
      )}

      {/* 2. ENVIRONMENTAL SOUND ALERT POPUP */}
      {activeSoundAlert && (
        <div
          role="alert"
          aria-live="assertive"
          className={`p-5 rounded-3xl border-4 shadow-2xl flex flex-col items-center text-center gap-3 transition-all ${
            activeSoundAlert.priority === 'high'
              ? 'bg-[#550606] border-[#FF453A] text-white'
              : 'bg-[#0E2F5E] border-[#0A84FF] text-white'
          }`}
        >
          <div className="flex items-center gap-2 px-4 py-1 rounded-full bg-white/20 text-white font-black text-xs uppercase tracking-wider">
            {activeSoundAlert.type === 'doorbell' && <Bell className="w-4 h-4 text-[#FFD60A]" />}
            {activeSoundAlert.type === 'horn' && <AlertTriangle className="w-4 h-4 text-[#FF453A]" />}
            {activeSoundAlert.type === 'blast' && <Zap className="w-4 h-4 text-[#FF2D55]" />}
            {activeSoundAlert.type === 'knock' && <HandMetal className="w-4 h-4 text-[#0A84FF]" />}
            <span>ENVIRONMENTAL SOUND</span>
          </div>

          <h2 className="text-2xl md:text-3xl font-black uppercase tracking-wide">
            {activeSoundAlert.title}
          </h2>

          <p className="text-base text-neutral-200">
            {activeSoundAlert.description}
          </p>

          <div className="flex items-center gap-2 px-4 py-1.5 rounded-xl bg-black/50 border border-white/30 text-sm font-black text-[#FFD60A]">
            {getDirectionVisual(activeSoundAlert.direction).icon}
            <span>{getDirectionVisual(activeSoundAlert.direction).label}</span>
          </div>

          <button
            type="button"
            onClick={onDismissSoundAlert}
            className="w-full mt-2 py-3 rounded-2xl bg-white hover:bg-neutral-200 text-black font-black text-base uppercase tracking-wider transition-all cursor-pointer"
          >
            DISMISS
          </button>
        </div>
      )}

      {/* 3. REAL-TIME AUDIO SPECTRUM EQUALIZER */}
      <AudioVisualizer
        micActive={micActive}
        volume={micVolume}
        frequencyBands={frequencyBands}
        speechError={speechError}
        micLabel={micDeviceLabel}
      />

      {/* 4. LIVE SPEECH-TO-TEXT TRANSMISSION CARD */}
      <div className="p-4 md:p-5 rounded-3xl bg-[#15151A] border-2 border-neutral-800 flex flex-col gap-3 shadow-xl">
        <div className="flex items-center justify-between border-b border-neutral-800 pb-3">
          <div className="flex items-center gap-2.5">
            <div
              className={`p-2 rounded-xl ${
                micActive ? 'bg-[#32D74B]/20 text-[#32D74B]' : 'bg-neutral-800 text-neutral-500'
              }`}
            >
              <Mic className="w-5 h-5 animate-pulse" />
            </div>
            <div>
              <h2 className="text-lg font-black text-white flex items-center gap-2">
                <span>Live Speech Transmission</span>
                {micActive && (
                  <span className="flex h-2.5 w-2.5 relative">
                    <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-[#32D74B] opacity-75"></span>
                    <span className="relative inline-flex rounded-full h-2.5 w-2.5 bg-[#32D74B]"></span>
                  </span>
                )}
              </h2>
              <p className="text-xs text-neutral-400">
                Continuous speech to text for hearing what others speak
              </p>
            </div>
          </div>

          {transcripts.length > 0 && (
            <button
              type="button"
              onClick={onClearTranscripts}
              aria-label="Clear transcript"
              className="p-2 rounded-xl text-neutral-400 hover:text-white hover:bg-neutral-800 transition-colors cursor-pointer"
            >
              <Trash2 className="w-4 h-4" />
            </button>
          )}
        </div>

        {/* Live Interim Transcript Bubble (updates immediately while words are being spoken) */}
        {interimTranscript && (
          <div className="p-3.5 rounded-2xl bg-[#23232B] border border-[#FFD60A]/50 text-[#FFD60A] text-lg font-bold animate-pulse">
            <span className="text-xs font-mono uppercase tracking-wider block text-neutral-400 mb-1">
              Speaking right now...
            </span>
            "{interimTranscript}"
          </div>
        )}

        {/* Finalized Transcripts Feed */}
        <div className="min-h-[140px] max-h-[260px] overflow-y-auto space-y-2.5 pr-1 flex flex-col-reverse">
          {transcripts.length === 0 && !interimTranscript ? (
            <div className="h-32 flex flex-col items-center justify-center text-center p-4 text-neutral-500">
              <MessageSquare className="w-8 h-8 mb-2 opacity-50" />
              <p className="text-sm font-semibold">Listening for speech...</p>
              <p className="text-xs text-neutral-600 mt-1">
                Words spoken by anyone near you will appear here instantly.
              </p>
            </div>
          ) : (
            transcripts.map((t) => (
              <div
                key={t.id}
                className={`p-3.5 rounded-2xl text-left border ${
                  t.isCallingName
                    ? 'bg-[#FFD60A]/10 border-[#FFD60A] text-white'
                    : 'bg-[#1C1C22] border-neutral-800 text-neutral-100'
                }`}
              >
                <div className="flex items-center justify-between text-xs text-neutral-400 mb-1">
                  <span className="font-bold text-neutral-300">{t.speaker}</span>
                  <span className="font-mono text-[11px]">
                    {new Date(t.timestamp).toLocaleTimeString([], {
                      hour: '2-digit',
                      minute: '2-digit',
                      second: '2-digit',
                    })}
                  </span>
                </div>
                <p className="text-base md:text-lg font-medium leading-relaxed">
                  {t.text}
                </p>
              </div>
            ))
          )}
        </div>

        {/* Direct Text Transmission Input */}
        <form onSubmit={handleSendText} className="flex gap-2 pt-2 border-t border-neutral-800">
          <input
            type="text"
            value={typedText}
            onChange={(e) => setTypedText(e.target.value)}
            placeholder={`Type speech or call "${userName}"...`}
            className="flex-1 px-4 py-2.5 rounded-xl bg-black border border-neutral-700 text-white text-sm focus:border-[#FFD60A] outline-none"
          />
          <button
            type="submit"
            className="px-4 py-2.5 rounded-xl bg-[#FFD60A] hover:bg-[#e6c008] text-black font-black text-sm uppercase flex items-center gap-1.5 cursor-pointer shadow-md"
          >
            <span>Transmit</span>
            <Send className="w-3.5 h-3.5" />
          </button>
        </form>

        {/* Quick Say Buttons */}
        <div className="flex flex-wrap gap-1.5 pt-1 text-xs">
          <span className="text-neutral-500 py-1">Quick transmit:</span>
          {[
            `Hey ${userName}!`,
            `Someone is at the door`,
            `Dinner is ready`,
            `Look at this`,
          ].map((phrase) => (
            <button
              key={phrase}
              type="button"
              onClick={() => onDirectSpeechInput(phrase)}
              className="px-2.5 py-1 rounded-lg bg-neutral-900 hover:bg-neutral-800 border border-neutral-800 text-neutral-300 hover:text-white transition-all cursor-pointer"
            >
              "{phrase}"
            </button>
          ))}
        </div>
      </div>

      {/* 5. CAMERA PREVIEW TOGGLE (Allows Deaf users to also see camera view) */}
      <div className="p-4 rounded-3xl bg-[#15151A] border-2 border-neutral-800 flex flex-col gap-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Camera className="w-5 h-5 text-[#32D74B]" />
            <h3 className="text-base font-black text-white uppercase tracking-wide">
              Camera Vision Sensor
            </h3>
          </div>
          <button
            type="button"
            onClick={() => setShowCamera(!showCamera)}
            className="flex items-center gap-1 text-xs font-bold text-[#FFD60A] hover:underline cursor-pointer"
          >
            <span>{showCamera ? 'Hide Camera' : 'Show Camera Feed'}</span>
            {showCamera ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
          </button>
        </div>

        {showCamera && (
          <CameraFeed
            stream={cameraStream}
            cameraActive={cameraActive}
            cameraError={cameraError}
            cameraLabel={cameraLabel}
            detectedObjects={detectedObjects}
            videoRef={videoElementRef}
            onRetryCamera={onRetryCamera}
            onImageUploaded={onImageUploaded}
            heightClass="h-[220px]"
          />
        )}
      </div>

      {/* 6. ENVIRONMENTAL SOUND SENSING STATUS & TEST TRIGGERS */}
      <div className="p-4 rounded-3xl bg-[#15151A] border-2 border-neutral-800 flex flex-col gap-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Radio className="w-5 h-5 text-[#FFD60A]" />
            <h3 className="text-base font-black text-white uppercase tracking-wide">
              Active Sound Monitoring
            </h3>
          </div>
          <button
            type="button"
            onClick={() => setShowSimulators(!showSimulators)}
            className="text-xs font-bold text-[#FFD60A] hover:underline cursor-pointer"
          >
            {showSimulators ? 'Hide Test Triggers' : 'Test Sound Alerts'}
          </button>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-4 gap-2 text-xs">
          <div className="p-2.5 rounded-xl bg-black border border-neutral-800 flex items-center gap-2">
            <Bell className="w-4 h-4 text-[#FFD60A]" />
            <span className="font-bold text-neutral-300">Doorbell</span>
          </div>
          <div className="p-2.5 rounded-xl bg-black border border-neutral-800 flex items-center gap-2">
            <AlertTriangle className="w-4 h-4 text-[#FF453A]" />
            <span className="font-bold text-neutral-300">Car Horn</span>
          </div>
          <div className="p-2.5 rounded-xl bg-black border border-neutral-800 flex items-center gap-2">
            <Zap className="w-4 h-4 text-[#FF2D55]" />
            <span className="font-bold text-neutral-300">Loud Blast</span>
          </div>
          <div className="p-2.5 rounded-xl bg-black border border-neutral-800 flex items-center gap-2">
            <HandMetal className="w-4 h-4 text-[#0A84FF]" />
            <span className="font-bold text-neutral-300">Door Knock</span>
          </div>
        </div>

        {/* Sound Test Simulator buttons */}
        {showSimulators && (
          <div className="p-3 rounded-2xl bg-black border border-neutral-700 space-y-2">
            <p className="text-xs text-neutral-400 font-semibold">
              Instant test triggers (exercises real visual alert overlays):
            </p>
            <div className="grid grid-cols-2 md:grid-cols-5 gap-2">
              <button
                type="button"
                onClick={() => onTriggerSimulatedSound('doorbell')}
                className="p-2 rounded-xl bg-neutral-800 hover:bg-neutral-700 text-xs font-bold text-[#FFD60A] text-center cursor-pointer transition-all"
              >
                🔔 Doorbell
              </button>
              <button
                type="button"
                onClick={() => onTriggerSimulatedSound('horn')}
                className="p-2 rounded-xl bg-neutral-800 hover:bg-neutral-700 text-xs font-bold text-[#FF453A] text-center cursor-pointer transition-all"
              >
                🚗 Car Horn
              </button>
              <button
                type="button"
                onClick={() => onTriggerSimulatedSound('blast')}
                className="p-2 rounded-xl bg-neutral-800 hover:bg-neutral-700 text-xs font-bold text-[#FF2D55] text-center cursor-pointer transition-all"
              >
                💥 Loud Blast
              </button>
              <button
                type="button"
                onClick={() => onTriggerSimulatedSound('knock')}
                className="p-2 rounded-xl bg-neutral-800 hover:bg-neutral-700 text-xs font-bold text-[#0A84FF] text-center cursor-pointer transition-all"
              >
                🚪 Knock
              </button>
              <button
                type="button"
                onClick={() => onTriggerSimulatedSound('name')}
                className="p-2 rounded-xl bg-neutral-800 hover:bg-neutral-700 text-xs font-bold text-white text-center cursor-pointer transition-all"
              >
                🗣️ Call "{userName}"
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
