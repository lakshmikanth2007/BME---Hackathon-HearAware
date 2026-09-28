import React, { useRef, useEffect, useState } from 'react';
import { Camera, CheckCircle, RefreshCw, Upload, AlertCircle } from 'lucide-react';
import { DetectedObject } from '../types/awareness';

interface CameraFeedProps {
  stream: MediaStream | null;
  cameraActive: boolean;
  cameraError?: string;
  cameraLabel?: string;
  detectedObjects: DetectedObject[];
  targetQuery?: string | null;
  heightClass?: string;
  onRetryCamera: () => void;
  onImageUploaded?: (img: HTMLImageElement) => void;
  videoRef: React.RefObject<HTMLVideoElement>;
}

export const CameraFeed: React.FC<CameraFeedProps> = ({
  stream,
  cameraActive,
  cameraError,
  cameraLabel,
  detectedObjects,
  targetQuery,
  heightClass = 'h-[240px] md:h-[280px]',
  onRetryCamera,
  onImageUploaded,
  videoRef,
}) => {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [resolution, setResolution] = useState<string>('Detecting...');

  useEffect(() => {
    const video = videoRef.current;
    if (video && stream) {
      video.srcObject = stream;
      video
        .play()
        .then(() => {
          setResolution(`${video.videoWidth || 640}x${video.videoHeight || 480}`);
        })
        .catch((err) => {
          console.warn('Video play error:', err);
        });
    }
  }, [stream, videoRef]);

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !onImageUploaded) return;

    const img = new Image();
    img.onload = () => {
      onImageUploaded(img);
      setResolution(`${img.naturalWidth}x${img.naturalHeight} (Photo)`);
    };
    img.src = URL.createObjectURL(file);
  };

  return (
    <div
      className={`relative w-full ${heightClass} bg-neutral-950 rounded-3xl overflow-hidden border-2 border-neutral-800 shadow-2xl flex items-center justify-center`}
    >
      {/* Real HTML Video element */}
      <video
        ref={videoRef}
        autoPlay
        playsInline
        muted
        onLoadedMetadata={(e) => {
          const v = e.currentTarget;
          v.play().catch(() => {});
          setResolution(`${v.videoWidth}x${v.videoHeight}`);
        }}
        className="w-full h-full object-cover"
      />

      {/* Live Object Detection Bounding Boxes Overlay */}
      <div className="absolute inset-0 pointer-events-none">
        {detectedObjects.map((d) => {
          const v = videoRef.current;
          const vw = v?.videoWidth || 640;
          const vh = v?.videoHeight || 480;

          const left = (d.bbox[0] / vw) * 100;
          const top = (d.bbox[1] / vh) * 100;
          const width = (d.bbox[2] / vw) * 100;
          const height = (d.bbox[3] / vh) * 100;

          const isTarget =
            targetQuery && d.class.toLowerCase().includes(targetQuery.toLowerCase());

          return (
            <div
              key={d.id}
              style={{
                left: `${left}%`,
                top: `${top}%`,
                width: `${width}%`,
                height: `${height}%`,
              }}
              className={`absolute border-2 rounded-lg transition-all ${
                isTarget
                  ? 'border-[#32D74B] bg-[#32D74B]/20 shadow-[0_0_12px_#32D74B]'
                  : d.isObstacle
                  ? 'border-[#FF453A] bg-[#FF453A]/25 shadow-[0_0_12px_#FF453A]'
                  : 'border-[#FFD60A] bg-[#FFD60A]/15'
              }`}
            >
              <div
                className={`absolute -top-6 left-0 px-2 py-0.5 rounded text-[10px] font-black uppercase tracking-wider whitespace-nowrap shadow-md ${
                  isTarget
                    ? 'bg-[#32D74B] text-black'
                    : d.isObstacle
                    ? 'bg-[#FF453A] text-white'
                    : 'bg-black/90 text-[#FFD60A] border border-[#FFD60A]/40'
                }`}
              >
                {d.class} · {d.distanceLabel}
              </div>
            </div>
          );
        })}
      </div>

      {/* Top Header Badge */}
      <div className="absolute top-3 left-3 flex items-center gap-2 px-3 py-1.5 rounded-full bg-black/80 backdrop-blur-md border border-neutral-700 text-xs font-black text-white">
        <span className="flex h-2.5 w-2.5 relative">
          <span
            className={`animate-ping absolute inline-flex h-full w-full rounded-full opacity-75 ${
              cameraActive ? 'bg-[#32D74B]' : 'bg-[#FF453A]'
            }`}
          ></span>
          <span
            className={`relative inline-flex rounded-full h-2.5 w-2.5 ${
              cameraActive ? 'bg-[#32D74B]' : 'bg-[#FF453A]'
            }`}
          ></span>
        </span>
        <Camera className="w-3.5 h-3.5 text-[#32D74B]" />
        <span>{cameraLabel || 'LIVE SENSOR'}</span>
        <span className="text-[10px] text-neutral-400 font-mono">({resolution})</span>
      </div>

      {/* Bottom Counter */}
      <div className="absolute bottom-3 left-3 px-3 py-1 rounded-full bg-black/80 backdrop-blur-md text-xs font-bold text-neutral-300 border border-neutral-800">
        {detectedObjects.length} object{detectedObjects.length !== 1 ? 's' : ''} detected
      </div>

      {/* Offline / Error Overlay */}
      {!cameraActive && (
        <div className="absolute inset-0 bg-black/95 flex flex-col items-center justify-center p-5 text-center gap-3">
          <AlertCircle className="w-12 h-12 text-[#FFD60A]" />
          <div>
            <h4 className="text-lg font-black text-white">Camera Feed Offline</h4>
            <p className="text-xs text-neutral-400 max-w-xs mt-1">
              {cameraError ||
                'Allow camera permission or upload a photo to test AI visual recognition.'}
            </p>
          </div>

          <div className="flex flex-wrap gap-2 justify-center mt-1">
            <button
              type="button"
              onClick={onRetryCamera}
              className="px-4 py-2 rounded-xl bg-[#FFD60A] text-black font-black text-xs uppercase tracking-wider hover:bg-[#e6c008] transition-all cursor-pointer flex items-center gap-1.5"
            >
              <RefreshCw className="w-3.5 h-3.5" />
              <span>Retry Camera</span>
            </button>

            <button
              type="button"
              onClick={() => fileInputRef.current?.click()}
              className="px-4 py-2 rounded-xl bg-neutral-800 hover:bg-neutral-700 text-white font-bold text-xs uppercase tracking-wider cursor-pointer transition-all flex items-center gap-1.5"
            >
              <Upload className="w-3.5 h-3.5" />
              <span>Upload Test Photo</span>
            </button>
            <input
              ref={fileInputRef}
              type="file"
              accept="image/*"
              onChange={handleFileChange}
              className="hidden"
            />
          </div>
        </div>
      )}
    </div>
  );
};
