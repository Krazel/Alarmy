"""Reproduce source-level metrics from exported XCTest attachments."""
import json, pathlib, sys
evidence = pathlib.Path(sys.argv[1])
destination = pathlib.Path(sys.argv[2])
manifest = json.loads((evidence/'manifest.json').read_text())
attachment = next(a for g in manifest for a in g['attachments'] if 'real-recognition-benchmark' in a['suggestedHumanReadableName'])
rows = json.loads((evidence/attachment['exportedFileName']).read_text())
classes = ['snore','cough','breath','voice','other']
report = {'sources':len({r['file'] for r in rows}), 'derivedCases':len(rows), 'classes':classes,
          'model':'Apple SoundAnalysis version1', 'windowsSeconds':[1,3], 'threshold':0.65,
          'limits':'Small author-labelled CC0 corpus, repeated evaluation; other means abstention. Variants share sources. No clinical or physical overnight accuracy claimed.', 'conditions':{}}
for condition in sorted({r['condition'] for r in rows}):
 subset = [r for r in rows if r['condition']==condition]
 result = {}
 for split in ['all','development','validation']:
  group = subset if split=='all' else [r for r in subset if r['split']==split]
  matrix = [[sum(r['expected']==actual and r['predicted']==predicted for r in group) for predicted in classes] for actual in classes]
  per_class = {}
  for i,kind in enumerate(classes):
   tp=matrix[i][i]; n=sum(matrix[i]); predicted=sum(row[i] for row in matrix)
   per_class[kind]={'sources':n,'truePositive':tp,'falseNegative':n-tp,'falsePositive':predicted-tp,'recall':tp/n if n else None,'precision':tp/predicted if predicted else None}
  result[split]={'cases':len(group),'correctDominant':sum(r['expected']==r['predicted'] for r in group),'matrix':matrix,'perClass':per_class,
                 'confusions':[{'file':r['file'],'expected':r['expected'],'predicted':r['predicted']} for r in group if r['expected']!=r['predicted']]}
 report['conditions'][condition]=result
report['cleanPipeline']=[{'file':r['file'],'expected':r['expected'],'capturedClips':r['capturedClips']} for r in rows if r['condition']=='clean']
report['rawRows']=rows
destination.mkdir(parents=True,exist_ok=True)
(destination/'recognition-metrics.json').write_text(json.dumps(report,indent=2)+'\n')
for name,condition in report['conditions'].items():
 a=condition['all'];print(name,a['correctDominant'],'/',a['cases'],a['confusions'])
