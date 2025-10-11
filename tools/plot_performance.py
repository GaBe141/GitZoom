import json
import sys
from pathlib import Path
import matplotlib.pyplot as plt

if len(sys.argv) < 2:
    print('Usage: plot_performance.py <baseline.json>')
    sys.exit(2)

p = Path(sys.argv[1])
if not p.exists():
    print('File not found:', p)
    sys.exit(2)

data = json.loads(p.read_text())
names = [d['Name'] for d in data]
avgs = [d['AvgMs'] for d in data]

plt.style.use('ggplot')
fig, ax = plt.subplots(figsize=(8,4))
ax.barh(names, avgs, color=['#2b8cbe','#7bccc4','#a6bddb','#d0d1e6'][:len(names)])
ax.set_xlabel('Average elapsed (ms)')
ax.set_title('Performance baseline — Avg elapsed per scenario')
for i,v in enumerate(avgs):
    ax.text(v + max(avgs)*0.01, i, f"{v:.0f} ms", va='center')

out = p.parent / ('plot-' + p.stem + '.png')
fig.tight_layout()
fig.savefig(out)
print('Wrote', out)
