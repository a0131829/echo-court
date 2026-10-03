"""Original 60-second instrumental loop: 64 BPM, felt keys, harp and soft pad.
All oscillators and note sequences are made locally; no samples or external tracks.
"""
from pathlib import Path
import numpy as np
from scipy.io.wavfile import write
RATE=44100
BEAT=60/64
SECONDS=64*BEAT
N=round(RATE*SECONDS)
out=np.zeros((N,2),np.float64)

def note(midi,at,duration,gain,pan=0,kind='keys'):
 t=np.arange(round(duration*RATE))/RATE
 f=440*2**((midi-69)/12)
 if kind=='pad':
  wave=(np.sin(2*np.pi*f*t)+.18*np.sin(2*np.pi*f*2*t))/1.18
  env=np.sin(np.pi*np.minimum(t/duration,1))**2
 else:
  wave=np.sin(2*np.pi*f*t)+.20*np.sin(2*np.pi*f*2*t)*np.exp(-t*2)+.065*np.sin(2*np.pi*f*3*t)*np.exp(-t*4)
  env=(1-np.exp(-t/0.018))*np.exp(-t/(1.6 if kind=='keys' else 1.0))
  env*=np.minimum((duration-t)/.3,1).clip(0,1)
 wave*=env*gain
 idx=(round(at*RATE)+np.arange(len(t)))%N
 out[idx,0]+=wave*np.sqrt((1-pan)/2)
 out[idx,1]+=wave*np.sqrt((1+pan)/2)

chords=[[50,57,61,66],[43,54,59,62],[47,54,57,62],[45,52,59,64]]
melodies=[[74,78,81],[78,76],[74,71,74],[76,69],[78,81,83],[81,78],[78,74,71],[76,74]]
for bar in range(16):
 at=bar*4*BEAT
 chord=chords[(bar//2)%4]
 for k,m in enumerate(chord):
  note(m,at,5.5*BEAT,.025,(-.5+k/3),'pad')
  note(m+12,at+(.1+k*.85)*BEAT,3.5,.032,(-.55+k*.36),'harp')
 for k,m in enumerate(melodies[bar%8]):
  note(m,at+([.5,2.0,3.25][k])*BEAT,4.8,.075, .17*np.sin(bar), 'keys')
# Circular tails continue across the loop boundary, so restarting adds no seam.
dry=out.copy()
for delay,gain in [(.173,.13),(.293,.10),(.457,.08),(.683,.06),(.991,.035)]:
 out+=np.roll(dry,round(delay*RATE),axis=0)[:,::-1]*gain
out*=.40/np.max(np.abs(out))
path=Path(__file__).resolve().parents[1]/'assets'/'courtyard_music.wav'
write(path,RATE,(out*32767).astype(np.int16))
print('60s loop, peak',np.max(np.abs(out)),'boundary step',np.max(np.abs(out[0]-out[-1])))
