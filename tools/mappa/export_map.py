import json
g=json.load(open('graph_final.json'))
W,H=3200,2977
SYS=[ # id, nome, cultura box (x,y), bbox, pianeta
 ('trapped','Pianeta Vagabondo Catturato',(110,505),(40,30,620,560)),
 ('desert','Mondo Desertico',(1224,118),(1316,30,1690,480)),
 ('biosphere','Biosfera Interstellare',(1066,900),(970,430,1380,890)),
 ('moon','Luna Abitata',(3088,520),(2600,30,3130,570)),
 ('water','Mondo Acquatico',(2408,470),(2140,560,2580,1020)),('water','Mondo Acquatico',(2408,470),(2600,1040,2680,1120)),
 ('colony','Mondo Colonia',(780,1077),(370,1070,770,1400)),
 ('polluted','Pianeta Inquinato',(3063,1717),(2620,1220,3170,1640)),
 ('jungle','Mondo Giungla',(380,1980),(30,1530,570,1930)),
 ('giant','Pianeta Gigante',(1804,1724),(1380,1690,1760,2230)),
 ('multigen','Nave Multigenerazionale',(2615,1810),(2130,1630,2560,2070)),
 ('ice','Pianeta di Ghiaccio',(662,2644),(20,2390,600,2940)),
 ('asteroid','Sistema di Asteroidi',(1304,2849),(1310,2330,2320,2930)),
 ('wartorn','Sistema Devastato',(3075,2392),(2560,2300,3170,2900)),
 ('station','Pianeta Stazione Spaziale',(1791,1212),(1300,450,2330,1420)),
 ('supergiant','Supergigante',None,(590,1980,1000,2370)),
 ('supernova','Supernova',None,(2000,40,2310,360)),
]
ORB={175:'Rainfall',182:'Rumbleport',179:'Desolation Landing',180:'Dryport',184:'Bypass',177:'Minion',181:'Moonport',186:'Whaleport',188:'Wet Landing',191:'Comfort Station',195:'Cobbleport',227:'Shuttlestop',196:'Paintfall',199:'Poison Port',200:'Jewelport',202:'Jellybeast Landing',205:'Goliath',204:'Grandport',206:'Greathome',229:'Neutron Port',220:'Ice Station',212:'Aerie',213:'Airhome',210:'Terror Station',219:"Titan's Tower"}
nodes=g['nodes']
def sysof(n):
    for s in SYS:
        x0,y0,x1,y1=s[3]
        if x0<=n['x']<=x1 and y0<=n['y']<=y1: return s[0]
    return ''
# ordine: per posizione
nodes.sort(key=lambda n:(n['y']//150,n['x']))
idmap={n['id']:i for i,n in enumerate(nodes)}
out=[]
for i,n in enumerate(nodes):
    k=n['kind']
    d={'i':i,'k':k,'x':round(n['x']/W,5),'y':round(n['y']/H,5),'s':sysof(n)}
    if k in('dot','oval'): d['c']=n['color'][0]  # r y b
    if k=='oval': d['p']=n['pen']
    if n['id'] in ORB: d['o']=ORB[n['id']]
    if k=='nav':
        d['ex']={p:idmap[v] for p,v in n['exits'].items()}
        if 'jump' in n: d['j']=idmap[n['jump']]
    if k=='base': d['s']=''
    out.append(d)
edges=sorted([sorted([idmap[a],idmap[b]]) for a,b in g['edges']])
# città sullo stesso pianeta (Air Foil): gruppi
cities=[d for d in out if d['k']=='city']
from collections import defaultdict
bys=defaultdict(list)
for c in cities: bys[c['s']].append(c['i'])
foil=[v for v in bys.values() if len(v)>1]
seen=set();SYS2=[]
for s in SYS:
    if s[0] not in seen: seen.add(s[0]); SYS2.append(s)
systems=[{'id':s[0],'nome':s[1],'box':[round(s[2][0]/W,4),round(s[2][1]/H,4)] if s[2] else None} for s in SYS2]
json.dump({'nodes':out,'edges':edges,'systems':systems,'foil':foil},open('/home/claude/merchant-of-venus/assets/data/mappa.json','w'),separators=(',',':'))
from collections import Counter
print(len(out),len(edges),Counter(d['k'] for d in out))
print(Counter(d['s'] for d in out if d['k'] in('orbit','city','scity','qbox','nav')))
print(foil)
for d in out:
    if d['k'] in('orbit','city','scity','qbox') and not d['s']: print('NOSYS',d)
