import React, { useState } from 'react';
import {
  AlertTriangle,
  ArrowDown,
  ArrowLeft,
  ArrowRight,
  ArrowUp,
  Camera,
  CheckCircle,
  Crosshair,
  ExternalLink,
  Eye,
  HelpCircle,
  Mic,
  MicOff,
  Search,
  Sparkles,
  StopCircle,
  Volume2,
} from 'lucide-react';
import { DetectedObject, ObstacleAlert } from '../types/awareness';
import { CameraFeed } from './CameraFeed';
import { AudioVisualizer } from './AudioVisualizer';

interface BlindViewProps {
  videoStream: MediaStream | null;
  cameraActive: boolean;
  cameraError?: string;
  cameraDeviceLabel?: string;
  detectedObjects: DetectedObject[];
  targetQuery: string | null;
  foundTarget: DetectedObject | null;
  activeObstacle: ObstacleAlert | null;
  isVoiceListening: boolean;
  micActive: boolean;
  micVolume: number;
  frequencyBands: number[];
  micDeviceLabel?: string;
  speechError?: string;
  lastVoiceCommand: string | null;
  isIframeBlocked?: boolean;
  videoElementRef: React.RefObject<HTMLVideoElement>;
  onSetTarget: (target: string | null) => void;
  onTapScreenAnnounce: () => void;
  onManualVoiceInput: (command: string) => void;
  onRetryCamera: () => void;
  onImageUploaded?: (image: HTMLImageElement) => void;
}

export const BlindView: React.FC<BlindViewProps> = ({
  videoStream,
  cameraActive,
  cameraError,
  cameraDeviceLabel,
  detectedObjects,
  targetQuery,
  foundTarget,
  activeObstacle,
  isVoiceListening,
  micActive,
  micVolume,
  frequencyBands,
  micDeviceLabel,
  speechError,
  lastVoiceCommand,
  isIframeBlocked,
  videoElementRef,
  onSetTarget,
  onTapScreenAnnounce,
  onManualVoiceInput,
  onRetryCamera,
  onImageUploaded,
}) => {
  const [customInput, setCustomInput] = useState('');

  const getDirectionText = (dir: 'left' | 'ahead' | 'right') => {
    switch (dir) {
      case 'left':
        return 'ON YOUR LEFT';
      case 'right':
        return 'ON YOUR RIGHT';
      case 'ahead':
        return 'DIRECTLY AHEAD';
    }
  };

  const getDirectionIcon = (dir: 'left' | 'ahead' | 'right') => {
    switch (dir) {
      case 'left':
        return <ArrowLeft className="w-6 h-6 text-[#FFD60A]" />;
      case 'right':
        return <ArrowRight className="w-6 h-6 text-[#FFD60A]" />;
      case 'ahead':
        return <ArrowUp className="w-6 h-6 text-[#FFD60A]" />;
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
                Open in a dedicated full tab to enable browser camera and microphone permissions.
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

      {/* 1. AUDIBLE VOICE ACTIVATION BANNER */}
      <div
        onClick={onTapScreenAnnounce}
        className="p-4 rounded-3xl bg-[#15151A] border-2 border-[#FFD60A] text-left cursor-pointer hover:bg-[#202028] transition-all shadow-xl select-none"
        role="button"
        tabIndex={0}
        aria-label="Tap anywhere for spoken status and audio feedback"
      >
        <div className="flex items-center justify-between mb-2">
          <div className="flex items-center gap-2">
            <div className="p-2 rounded-xl bg-[#FFD60A] text-black">
              <Mic className="w-5 h-5 animate-pulse" />
            </div>
            <div>
              <span className="text-xs font-mono font-bold uppercase tracking-wider text-[#FFD60A]">
                Voice Activated Assistant
              </span>
              <h2 className="text-lg font-black text-white">
                Everything is Audible & Voice-Driven
              </h2>
            </div>
          </div>
          <span className="text-xs px-2.5 py-1 rounded-full bg-[#FFD60A]/20 text-[#FFD60A] font-bold border border-[#FFD60A]/40">
            VOICE READY
          </span>
        </div>

        <p className="text-sm text-neutral-300 font-medium">
          Say <strong className="text-[#FFD60A]">"Find bottle"</strong>,{' '}
          <strong className="text-[#FFD60A]">"Find cup"</strong>,{' '}
          <strong className="text-[#FFD60A]">"Find chair"</strong>, or{' '}
          <strong className="text-[#FFD60A]">"Describe surroundings"</strong>.
        </p>

        {lastVoiceCommand && (
          <div className="mt-2.5 pt-2.5 border-t border-neutral-800 text-xs text-neutral-400 flex items-center gap-2">
            <Volume2 className="w-4 h-4 text-[#32D74B]" />
            <span>
              Voice recognized:{' '}
              <strong className="text-white font-mono">"{lastVoiceCommand}"</strong>
            </span>
          </div>
        )}
      </div>

      {/* 2. REAL-TIME AUDIO EQUALIZER (Visually proves microphone is hearing sound) */}
      <AudioVisualizer
        micActive={micActive}
        volume={micVolume}
        frequencyBands={frequencyBands}
        speechError={speechError}
        micLabel={micDeviceLabel}
      />

      {/* 3. OBSTACLE ALERT WARNING (DISTANCE & DIRECTION FROM USER'S POV) */}
      {activeObstacle && (
        <div
          role="alert"
          aria-live="assertive"
          className="p-5 rounded-3xl bg-[#5C0B0B] border-4 border-[#FF453A] text-white shadow-2xl animate-bounce flex flex-col items-center text-center gap-2"
        >
          <div className="flex items-center gap-2 px-3 py-1 rounded-full bg-white text-black text-xs font-black uppercase tracking-wider">
            <AlertTriangle className="w-4 h-4 text-red-600" />
            <span>OBSTACLE ALERT</span>
          </div>

          <h3 className="text-3xl font-black uppercase tracking-wide">
            {activeObstacle.objectName.toUpperCase()} AHEAD
          </h3>

          <div className="flex items-center justify-center gap-3 px-5 py-2.5 rounded-2xl bg-black/70 border-2 border-white">
            {getDirectionIcon(activeObstacle.direction)}
            <span className="text-xl font-black text-white">
              {getDirectionText(activeObstacle.direction)}
            </span>
          </div>

          <div className="px-4 py-1.5 rounded-xl bg-black/50 text-[#FFD60A] font-bold text-lg">
            Distance: {activeObstacle.distanceLabel} (~{activeObstacle.distanceFt} ft)
          </div>

          <p className="text-sm text-neutral-300 font-semibold mt-1">
            Careful: step slightly to the side to avoid bumping.
          </p>
        </div>
      )}

      {/* 4. TARGET OBJECT FINDING ASSISTANT */}
      {targetQuery && (
        <div className="p-5 rounded-3xl bg-[#0D2818] border-2 border-[#32D74B] text-white shadow-xl flex flex-col gap-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Crosshair className="w-5 h-5 text-[#32D74B] animate-spin" />
              <span className="text-xs font-mono uppercase tracking-wider text-[#32D74B] font-bold">
                Searching for Object
              </span>
            </div>
            <button
              type="button"
              onClick={() => onSetTarget(null)}
              className="flex items-center gap-1 text-xs font-bold text-neutral-300 hover:text-white px-2 py-1 rounded-lg bg-black/40 hover:bg-black/60 transition-all cursor-pointer"
            >
              <StopCircle className="w-3.5 h-3.5 text-red-400" />
              <span>Cancel Search</span>
            </button>
          </div>

          <div>
            <h3 className="text-2xl font-black uppercase text-white tracking-wide">
              Target: {targetQuery}
            </h3>
          </div>

          {foundTarget ? (
            <div className="p-4 rounded-2xl bg-black/60 border-2 border-[#32D74B] flex flex-col items-center text-center gap-2">
              <div className="flex items-center gap-2 text-[#32D74B] font-black text-lg">
                <CheckCircle className="w-6 h-6" />
                <span>FOUND {foundTarget.class.toUpperCase()}!</span>
              </div>

              <div className="flex items-center gap-2 text-2xl font-black text-[#FFD60A]">
                {getDirectionIcon(foundTarget.direction)}
                <span>{getDirectionText(foundTarget.direction)}</span>
              </div>

              <div className="text-base text-neutral-200 font-bold">
                Distance: {foundTarget.distanceLabel}
              </div>

              {foundTarget.direction === 'ahead' && (
                <div className="px-3 py-1 rounded-full bg-[#32D74B] text-black font-black text-xs uppercase tracking-wider">
                  Target is Centered · Reach Forward
                </div>
              )}
            </div>
          ) : (
            <div className="p-4 rounded-2xl bg-black/40 border border-neutral-700 text-center text-neutral-300 text-sm font-medium">
              Pan your camera slowly around the room to locate the {targetQuery}...
            </div>
          )}
        </div>
      )}

      {/* 5. LIVE CAMERA WITH REAL-TIME OBJECT DETECTIONS & BOUNDING BOXES */}
      <CameraFeed
        stream={videoStream}
        cameraActive={cameraActive}
        cameraError={cameraError}
        cameraLabel={cameraDeviceLabel}
        detectedObjects={detectedObjects}
        targetQuery={targetQuery}
        videoRef={videoElementRef}
        onRetryCamera={onRetryCamera}
        onImageUploaded={onImageUploaded}
      />

      {/* 6. ONE-TOUCH QUICK OBJECT FINDING BUTTONS */}
      <div className="p-4 rounded-3xl bg-[#15151A] border-2 border-neutral-800 flex flex-col gap-2.5">
        <div className="flex items-center justify-between">
          <h3 className="text-sm font-black text-white uppercase tracking-wide flex items-center gap-2">
            <Search className="w-4 h-4 text-[#FFD60A]" />
            <span>Find Object (Voice or One-Touch)</span>
          </h3>
          <span className="text-xs text-neutral-500 font-mono">Camera Guided</span>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
          {['bottle', 'cup', 'cell phone', 'chair', 'person', 'dining table', 'laptop', 'backpack'].map(
            (item) => (
              <button
                key={item}
                type="button"
                onClick={() => onSetTarget(item)}
                className={`p-3 rounded-2xl border text-sm font-black uppercase tracking-wider transition-all cursor-pointer ${
                  targetQuery === item
                    ? 'bg-[#32D74B] border-[#32D74B] text-black shadow-lg'
                    : 'bg-black border-neutral-800 text-neutral-200 hover:border-neutral-600 active:scale-95'
                }`}
              >
                {item === 'cell phone' ? 'Phone' : item === 'dining table' ? 'Table' : item}
              </button>
            )
          )}
        </div>
      </div>

      {/* 7. VOICE COMMANDS / DIRECT TEXT TRIGGER (Audibly Spoken in Response) */}
      <div className="p-4 rounded-3xl bg-[#15151A] border border-neutral-800 flex flex-col gap-2.5 text-xs text-neutral-400">
        <div className="flex items-center justify-between">
          <span className="text-neutral-300 font-bold flex items-center gap-1.5">
            <HelpCircle className="w-4 h-4 text-[#FFD60A]" />
            <span>Spoken Voice Commands:</span>
          </span>
          <span className="text-neutral-500 font-mono">Speak or Tap</span>
        </div>

        <div className="flex flex-wrap gap-1.5">
          {[
            'Find bottle',
            'Find chair',
            'Find phone',
            'Describe surroundings',
            'Check obstacles',
            'Stop',
          ].map((cmd) => (
            <button
              key={cmd}
              type="button"
              onClick={() => onManualVoiceInput(cmd)}
              className="px-3 py-1.5 rounded-lg bg-black hover:bg-neutral-800 border border-neutral-800 text-neutral-200 hover:text-white transition-all cursor-pointer font-medium"
            >
              "{cmd}"
            </button>
          ))}
        </div>

        {/* Custom text voice command input */}
        <form
          onSubmit={(e) => {
            e.preventDefault();
            if (!customInput.trim()) return;
            onManualVoiceInput(customInput.trim());
            setCustomInput('');
          }}
          className="flex gap-2 pt-2 border-t border-neutral-800 mt-1"
        >
          <input
            type="text"
            value={customInput}
            onChange={(e) => setCustomInput(e.target.value)}
            placeholder="Type voice command (e.g. Find keys, Describe)..."
            className="flex-1 px-3.5 py-2 rounded-xl bg-black border border-neutral-700 text-white text-xs outline-none focus:border-[#FFD60A]"
          />
          <button
            type="submit"
            className="px-3.5 py-2 rounded-xl bg-[#FFD60A] text-black font-black uppercase text-xs cursor-pointer hover:bg-[#e6c008]"
          >
            Execute
          </button>
        </form>
      </div>
    </div>
  );
};
