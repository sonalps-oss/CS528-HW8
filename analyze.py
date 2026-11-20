#!/usr/bin/env python3
import argparse,csv,collections
p=argparse.ArgumentParser();p.add_argument('csv_file');a=p.parse_args()
r=list(csv.DictReader(open(a.csv_file)));good=[x for x in r if x['status']=='200'];zones=collections.Counter(x['zone'] for x in good)
print('Total',len(r),'Successful',len(good),'Errors',len(r)-len(good))
for zone,n in sorted(zones.items()):print(zone,n,f'{n/max(1,len(good))*100:.2f}%')
errors=[x for x in r if x['status']!='200']
if errors:print('First error',errors[0]['timestamp_utc'],'Last error',errors[-1]['timestamp_utc'])
