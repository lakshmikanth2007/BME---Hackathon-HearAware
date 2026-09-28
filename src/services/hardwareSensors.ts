export interface SensorStatus {
  camera: 'checking' | 'active' | 'denied' | 'unavailable' | 'off';
  mic: 'checking' | 'active' | 'denied' | 'unavailable' | 'off';
  cameraError?: string;
  micError?: string;
  cameraDeviceLabel?: string;
  micDeviceLabel?: string;
  isIframeBlocked?: boolean;
}

export class HardwareSensorsService {
  private mediaStream: MediaStream | null = null;
  private videoTrack: MediaStreamTrack | null = null;
  private audioTrack: MediaStreamTrack | null = null;

  public async startSensors(onStatusChange: (status: SensorStatus) => void): Promise<{
    stream: MediaStream | null;
    videoTrack: MediaStreamTrack | null;
    audioTrack: MediaStreamTrack | null;
    status: SensorStatus;
  }> {
    const status: SensorStatus = {
      camera: 'checking',
      mic: 'checking',
    };
    onStatusChange({ ...status });

    if (
      typeof navigator === 'undefined' ||
      !navigator.mediaDevices ||
      !navigator.mediaDevices.getUserMedia
    ) {
      status.camera = 'unavailable';
      status.mic = 'unavailable';
      status.cameraError = 'MediaDevices API not supported in this browser.';
      status.micError = 'MediaDevices API not supported in this browser.';
      onStatusChange({ ...status });
      return { stream: null, videoTrack: null, audioTrack: null, status };
    }

    const combinedStream = new MediaStream();

    // 1. Request unified audio + video with simple standard constraints
    try {
      const fullStream = await navigator.mediaDevices.getUserMedia({
        video: true,
        audio: true,
      });

      const vTracks = fullStream.getVideoTracks();
      const aTracks = fullStream.getAudioTracks();

      if (vTracks.length > 0) {
        this.videoTrack = vTracks[0];
        this.videoTrack.enabled = true;
        combinedStream.addTrack(this.videoTrack);
        status.camera = 'active';
        status.cameraDeviceLabel = this.videoTrack.label || 'Connected Camera';
      }

      if (aTracks.length > 0) {
        this.audioTrack = aTracks[0];
        this.audioTrack.enabled = true;
        combinedStream.addTrack(this.audioTrack);
        status.mic = 'active';
        status.micDeviceLabel = this.audioTrack.label || 'Connected Microphone';
      }
    } catch (unifiedErr: unknown) {
      console.warn('Unified getUserMedia failed; trying separate requests:', unifiedErr);
      const err = unifiedErr as { name?: string; message?: string };

      if (err.name === 'NotAllowedError' && typeof window !== 'undefined' && window.self !== window.top) {
        status.isIframeBlocked = true;
      }

      // 2A: Try Video only
      try {
        const vStream = await navigator.mediaDevices.getUserMedia({ video: true });
        const vTracks = vStream.getVideoTracks();
        if (vTracks.length > 0) {
          this.videoTrack = vTracks[0];
          this.videoTrack.enabled = true;
          combinedStream.addTrack(this.videoTrack);
          status.camera = 'active';
          status.cameraDeviceLabel = this.videoTrack.label || 'Camera';
        }
      } catch (vErr: unknown) {
        const ve = vErr as { name?: string; message?: string };
        status.camera = ve.name === 'NotAllowedError' ? 'denied' : 'unavailable';
        status.cameraError =
          ve.name === 'NotAllowedError'
            ? 'Camera permission denied. Allow camera in browser settings.'
            : ve.name === 'NotReadableError'
            ? 'Camera in use by another application.'
            : ve.message || ve.name || 'Camera unavailable';
      }

      // 2B: Try Audio only
      try {
        const aStream = await navigator.mediaDevices.getUserMedia({ audio: true });
        const aTracks = aStream.getAudioTracks();
        if (aTracks.length > 0) {
          this.audioTrack = aTracks[0];
          this.audioTrack.enabled = true;
          combinedStream.addTrack(this.audioTrack);
          status.mic = 'active';
          status.micDeviceLabel = this.audioTrack.label || 'Microphone';
        }
      } catch (aErr: unknown) {
        const ae = aErr as { name?: string; message?: string };
        status.mic = ae.name === 'NotAllowedError' ? 'denied' : 'unavailable';
        status.micError =
          ae.name === 'NotAllowedError'
            ? 'Microphone permission denied. Allow microphone in browser settings.'
            : ae.message || ae.name || 'Microphone unavailable';
      }
    }

    this.mediaStream = combinedStream.getTracks().length > 0 ? combinedStream : null;
    onStatusChange({ ...status });

    return {
      stream: this.mediaStream,
      videoTrack: this.videoTrack,
      audioTrack: this.audioTrack,
      status,
    };
  }

  public stopSensors(): void {
    if (this.videoTrack) {
      this.videoTrack.stop();
      this.videoTrack = null;
    }
    if (this.audioTrack) {
      this.audioTrack.stop();
      this.audioTrack = null;
    }
    if (this.mediaStream) {
      this.mediaStream.getTracks().forEach((t) => t.stop());
      this.mediaStream = null;
    }
  }

  public getStream(): MediaStream | null {
    return this.mediaStream;
  }
}

export const hardwareSensors = new HardwareSensorsService();
