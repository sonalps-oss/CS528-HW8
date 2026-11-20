#!/usr/bin/env python3
"""CS528 HW8 one-request-per-second client, logs the backend zone."""
import argparse, csv, time
from collections import Counter
from datetime import datetime,timezone
from urllib.request import Request,urlopen
p=argparse.ArgumentParser()
p.add_argument('--ip',default='34.133.74.194')
p.add_argument('--duration',type=int,default=120,help='0 for continuous until Ctrl-C')
p.add_argument('--output',default='hw8-client.csv')
p.add_argument('--path',default='/graph_data/0.html')
a=p.parse_args()
url=f'http://{a.ip}:8080{a.path}';counts=Counter();errors=0;start=time.monotonic();i=0
with open(a.output,'w',newline='') as f:
 w=csv.writer(f);w.writerow(['timestamp_utc','request','status','zone','latency_ms','error']);f.flush()
 try:
  while a.duration==0 or time.monotonic()-start<a.duration:
   tick=time.monotonic();i+=1;t=datetime.now(timezone.utc).isoformat();status=0;zone='UNKNOWN';error=''
   try:
    req=Request(url,headers={'Connection':'close'})
    with urlopen(req,timeout=4) as resp:
     status=resp.status;zone=resp.headers.get('X-Server-Zone','UNKNOWN');resp.read()
    if status==200 and zone!='UNKNOWN':counts[zone]+=1
    else:errors+=1
   except Exception as exc:error=str(exc);errors+=1
   latency=round((time.monotonic()-tick)*1000,2)
   w.writerow([t,i,status,zone,latency,error]);f.flush()
   print(f'{t} | Request {i} | Status {status} | Zone {zone} | {latency}ms | {error}',flush=True)
   time.sleep(max(0,1-(time.monotonic()-tick)))
 except KeyboardInterrupt:pass
print('SUCCESS',sum(counts.values()),'ERRORS',errors)
for zone,count in sorted(counts.items()):print(zone,count,round(100*count/max(1,sum(counts.values())),2))
