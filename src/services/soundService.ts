class SoundService {
  private ctx: AudioContext | null = null;

  private getContext(): AudioContext | null {
    if (typeof window === 'undefined') return null;
    if (!this.ctx) {
      const AudioCtx = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
      if (AudioCtx) {
        this.ctx = new AudioCtx();
      }
    }
    if (this.ctx && this.ctx.state === 'suspended') {
      this.ctx.resume().catch(() => {});
    }
    return this.ctx;
  }

  public playAlertSound(urgent = false): void {
    try {
      // Haptic feedback
      if (typeof navigator !== 'undefined' && 'vibrate' in navigator) {
        if (urgent) {
          navigator.vibrate([200, 100, 200, 100, 200]);
        } else {
          navigator.vibrate(150);
        }
      }

      const ctx = this.getContext();
      if (!ctx) return;

      const osc = ctx.createOscillator();
      const gain = ctx.createGain();

      osc.type = urgent ? 'sawtooth' : 'sine';
      osc.frequency.setValueAtTime(urgent ? 880 : 587.33, ctx.currentTime); // A5 or D5
      if (urgent) {
        osc.frequency.exponentialRampToValueAtTime(1174.66, ctx.currentTime + 0.15); // D6
      }

      gain.gain.setValueAtTime(0.2, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + (urgent ? 0.35 : 0.2));

      osc.connect(gain);
      gain.connect(ctx.destination);

      osc.start();
      osc.stop(ctx.currentTime + (urgent ? 0.35 : 0.2));
    } catch (e) {
      console.warn('Audio playback error:', e);
    }
  }
}

export const soundService = new SoundService();
