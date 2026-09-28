import { SoundAlert } from '../types/awareness';

export type OnSoundAlertCallback = (alert: SoundAlert) => void;
export type OnVolumeLevelCallback = (volumePercent: number, frequencyBands: number[]) => void;

export class AudioAnalyzerService {
  private audioCtx: AudioContext | null = null;
  private analyser: AnalyserNode | null = null;
  private sourceNode: MediaStreamAudioSourceNode | null = null;
  private muteGain: GainNode | null = null;
  private animId: number | null = null;
  private isRunning = false;
  private onAlert: OnSoundAlertCallback | null = null;
  private onVolume: OnVolumeLevelCallback | null = null;

  // Cooldown timers to reduce alert frequency
  private lastAlertTime: Record<string, number> = {};
  private lastGlobalAlertTime = 0;
  private sustainedHornCounter = 0;
  private sustainedDoorbellCounter = 0;
  private sustainedKnockCounter = 0;

  public start(
    audioTrack: MediaStreamTrack,
    onAlert: OnSoundAlertCallback,
    onVolume?: OnVolumeLevelCallback
  ): void {
    this.stop();
    this.onAlert = onAlert;
    this.onVolume = onVolume || null;
    this.isRunning = true;

    try {
      const AudioCtx =
        window.AudioContext ||
        (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
      if (!AudioCtx) return;

      this.audioCtx = new AudioCtx();
      if (this.audioCtx.state === 'suspended') {
        this.audioCtx.resume().catch(() => {});
      }

      const mediaStream = new MediaStream([audioTrack]);
      this.sourceNode = this.audioCtx.createMediaStreamSource(mediaStream);
      this.analyser = this.audioCtx.createAnalyser();
      this.analyser.fftSize = 512;
      this.analyser.smoothingTimeConstant = 0.3;

      this.muteGain = this.audioCtx.createGain();
      this.muteGain.gain.value = 0;

      this.sourceNode.connect(this.analyser);
      this.analyser.connect(this.muteGain);
      this.muteGain.connect(this.audioCtx.destination);

      const freqData = new Uint8Array(this.analyser.frequencyBinCount);
      const binCount = this.analyser.frequencyBinCount;

      const analyze = () => {
        if (!this.isRunning || !this.analyser) return;

        this.analyser.getByteFrequencyData(freqData);

        // 1. Calculate overall volume from frequency energy
        let totalEnergy = 0;
        for (let i = 0; i < binCount; i++) {
          totalEnergy += freqData[i];
        }
        const avgEnergy = totalEnergy / binCount;
        const volumePercent = Math.min(100, Math.round((avgEnergy / 80) * 100));

        // 2. Compute 8 frequency bands for UI visualizer
        const bands: number[] = [];
        const bandSize = Math.floor(binCount / 8);
        for (let b = 0; b < 8; b++) {
          let bSum = 0;
          for (let i = b * bandSize; i < (b + 1) * bandSize; i++) {
            bSum += freqData[i];
          }
          bands.push(Math.min(100, Math.round((bSum / bandSize / 255) * 100)));
        }

        if (this.onVolume) {
          this.onVolume(volumePercent, bands);
        }

        // 3. Band energies for sound classification
        // Low: Bins 1 - 6 (approx 80 - 450 Hz) - Knocks, thuds
        // Mid: Bins 7 - 18 (approx 450 - 1200 Hz) - Car horns, siren
        // High: Bins 19 - 45 (approx 1200 - 3000 Hz) - Doorbells, chimes
        let lowSum = 0;
        let midSum = 0;
        let highSum = 0;

        for (let i = 1; i <= 6; i++) lowSum += freqData[i];
        for (let i = 7; i <= 18; i++) midSum += freqData[i];
        for (let i = 19; i <= 45; i++) highSum += freqData[i];

        const lowAvg = lowSum / 6;
        const midAvg = midSum / 12;
        const highAvg = highSum / 27;

        const now = Date.now();
        // Enforce a minimum 8-second quiet period between ANY alerts to prevent overwhelming the user
        const canTriggerGlobal = now - this.lastGlobalAlertTime > 8000;

        // 1. LOUD BLAST / CLAP / EXPLOSION (Sudden high spike > 72%, cooldown: 15s)
        if (
          canTriggerGlobal &&
          volumePercent > 72 &&
          (!this.lastAlertTime['blast'] || now - this.lastAlertTime['blast'] > 15000)
        ) {
          this.lastAlertTime['blast'] = now;
          this.lastGlobalAlertTime = now;
          this.triggerAlert({
            id: `blast_${now}`,
            timestamp: new Date(),
            type: 'blast',
            title: 'LOUD BLAST DETECTED',
            description: 'Sudden high-volume impact or explosive sound',
            direction: 'ahead',
            priority: 'high',
            confidence: 0.95,
          });
        }

        // 2. CAR HORN (Mid-frequency dominant >= 52 sustained for 4+ samples, cooldown: 14s)
        if (midAvg > 52 && volumePercent > 20 && midAvg > lowAvg * 1.1) {
          this.sustainedHornCounter++;
          if (this.sustainedHornCounter >= 4) {
            if (
              canTriggerGlobal &&
              (!this.lastAlertTime['horn'] || now - this.lastAlertTime['horn'] > 14000)
            ) {
              this.lastAlertTime['horn'] = now;
              this.lastGlobalAlertTime = now;
              this.triggerAlert({
                id: `horn_${now}`,
                timestamp: new Date(),
                type: 'horn',
                title: 'CAR HORN BLARING',
                description: 'Vehicle horn or sustained siren sounding nearby',
                direction: 'ahead',
                priority: 'high',
                confidence: 0.9,
              });
            }
          }
        } else {
          this.sustainedHornCounter = Math.max(0, this.sustainedHornCounter - 1);
        }

        // 3. DOORBELL / CHIME (High harmonic >= 42, higher than low, sustained, cooldown: 14s)
        if (highAvg > 42 && volumePercent > 16 && highAvg > lowAvg * 1.25) {
          this.sustainedDoorbellCounter++;
          if (this.sustainedDoorbellCounter >= 4) {
            if (
              canTriggerGlobal &&
              (!this.lastAlertTime['doorbell'] || now - this.lastAlertTime['doorbell'] > 14000)
            ) {
              this.lastAlertTime['doorbell'] = now;
              this.lastGlobalAlertTime = now;
              this.triggerAlert({
                id: `doorbell_${now}`,
                timestamp: new Date(),
                type: 'doorbell',
                title: 'DOORBELL RINGING',
                description: 'Chime or doorbell melody detected',
                direction: 'ahead',
                priority: 'medium',
                confidence: 0.88,
              });
            }
          }
        } else {
          this.sustainedDoorbellCounter = Math.max(0, this.sustainedDoorbellCounter - 1);
        }

        // 4. DOOR KNOCK (Rhythmic low pulse, sustained 3+ pulses, cooldown: 14s)
        if (lowAvg > 48 && volumePercent > 18 && highAvg < 25) {
          this.sustainedKnockCounter++;
          if (this.sustainedKnockCounter >= 3) {
            if (
              canTriggerGlobal &&
              (!this.lastAlertTime['knock'] || now - this.lastAlertTime['knock'] > 14000)
            ) {
              this.lastAlertTime['knock'] = now;
              this.lastGlobalAlertTime = now;
              this.triggerAlert({
                id: `knock_${now}`,
                timestamp: new Date(),
                type: 'knock',
                title: 'DOOR KNOCKING',
                description: 'Rhythmic knocking sound detected',
                direction: 'ahead',
                priority: 'medium',
                confidence: 0.84,
              });
            }
          }
        } else {
          this.sustainedKnockCounter = Math.max(0, this.sustainedKnockCounter - 1);
        }

        this.animId = requestAnimationFrame(analyze);
      };

      this.animId = requestAnimationFrame(analyze);
    } catch (e) {
      console.warn('AudioAnalyzer start error:', e);
    }
  }

  private triggerAlert(alert: SoundAlert): void {
    if (this.onAlert) {
      this.onAlert(alert);
    }
  }

  public stop(): void {
    this.isRunning = false;
    if (this.animId) {
      cancelAnimationFrame(this.animId);
      this.animId = null;
    }
    if (this.sourceNode) {
      this.sourceNode.disconnect();
      this.sourceNode = null;
    }
    if (this.analyser) {
      this.analyser.disconnect();
      this.analyser = null;
    }
    if (this.muteGain) {
      this.muteGain.disconnect();
      this.muteGain = null;
    }
    if (this.audioCtx) {
      try {
        this.audioCtx.close();
      } catch {
        // ignore
      }
      this.audioCtx = null;
    }
    this.onAlert = null;
    this.onVolume = null;
    this.sustainedHornCounter = 0;
    this.sustainedDoorbellCounter = 0;
    this.sustainedKnockCounter = 0;
  }
}

export const audioAnalyzer = new AudioAnalyzerService();
