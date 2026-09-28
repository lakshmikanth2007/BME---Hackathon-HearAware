import React from 'react';
import { Mic, MicOff, Volume2 } from 'lucide-react';

interface AudioVisualizerProps {
  micActive: boolean;
  volume: number; // 0 - 100
  frequencyBands: number[]; // 8 bands 0 - 100
  speechError?: string;
  micLabel?: string;
}

export const AudioVisualizer: React.FC<AudioVisualizerProps> = ({
  micActive,
  volume,
  frequencyBands,
  speechError,
  micLabel,
}) => {
  return (
    <div className="w-full p-3.5 rounded-2xl bg-[#121217] border border-neutral-800 flex flex-col gap-2.5">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div
            className={`p-1.5 rounded-lg ${
              micActive ? 'bg-[#32D74B]/20 text-[#32D74B]' : 'bg-neutral-800 text-neutral-500'
            }`}
          >
            {micActive ? (
              <Mic className="w-4 h-4 animate-pulse" />
            ) : (
              <MicOff className="w-4 h-4" />
            )}
          </div>
          <div>
            <span className="text-xs font-black text-white flex items-center gap-1.5">
              <span>{micLabel || 'Microphone Audio Sensor'}</span>
              {micActive && (
                <span className="text-[10px] font-mono px-1.5 py-0.2 rounded bg-[#32D74B]/20 text-[#32D74B]">
                  LIVE
                </span>
              )}
            </span>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <span className="text-xs font-mono font-bold text-neutral-300">
            {micActive ? `${volume}% Input` : 'Off'}
          </span>
        </div>
      </div>

      {/* 8-band animated frequency equalizer */}
      <div className="flex items-end justify-between gap-1.5 h-8 px-2 py-1 bg-black rounded-xl border border-neutral-800/80">
        {Array.from({ length: 8 }).map((_, idx) => {
          const val = micActive && frequencyBands[idx] !== undefined ? frequencyBands[idx] : 5;
          const heightPercent = Math.max(8, val);

          return (
            <div
              key={idx}
              className="flex-1 bg-neutral-900 rounded-sm overflow-hidden flex flex-col justify-end h-full"
            >
              <div
                style={{ height: `${heightPercent}%` }}
                className={`w-full rounded-sm transition-all duration-75 ${
                  heightPercent > 60
                    ? 'bg-[#FF453A]'
                    : heightPercent > 25
                    ? 'bg-[#FFD60A]'
                    : 'bg-[#32D74B]'
                }`}
              />
            </div>
          );
        })}
      </div>

      {speechError && (
        <p className="text-[11px] text-[#FFD60A] font-semibold bg-[#2A1800] px-2.5 py-1 rounded-lg border border-[#FFD60A]/30">
          {speechError}
        </p>
      )}
    </div>
  );
};
