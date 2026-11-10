import json,math
g=json.load(open('graph_auto_frozen.json'))
N={n['id']:n for n in g['nodes']}
E=set(tuple(sorted(e)) for e in g['edges'])
def rm_node(i):
    global E
    N.pop(i,None); E={e for e in E if i not in e}
def add(a,b): E.add(tuple(sorted((a,b))))
def rm(a,b): E.discard(tuple(sorted((a,b))))
nid=[2000]
def new(kind,x,y,**kw):
    i=nid[0]; nid[0]+=1
    N[i]=dict(id=i,kind=kind,x=x,y=y,color=None,**kw); return i
# box classification
for i in range(175,222):
    pass
orbit_ids=[175,177,179,180,181,182,184,186,188,191,195,196,199,200,202,204,205,206,210,212,213,219,220]
q_ids=[176,178,183,185,187,189,190,192,193,194,197,198,201,203,207,208,209,211,214,215,216,217,218,221]
assert len(orbit_ids)==23 and len(q_ids)==24
for i in orbit_ids: N[i]['kind']='orbit'
for i in q_ids: N[i]['kind']='qbox'
rm_node(77)
# --- fixes
cA=new('city',1426,168); add(179,cA)
add(4,1005)
add(128,78); add(128,21)
cJ=new('city',150,1770); add(202,cJ)
cP=new('city',3058,1422); add(196,cP)
rm_node(1025); rm_node(1028)
r=new('asteroid',562,2544); add(49,r); add(r,56)
cI=new('city',160,2804); add(220,cI)
add(208,50); add(176,180); add(180,1005); add(157,204); add(157,206)
# --- nav circles: remove auto edges, then explicit exits
NAV={
 222:{3:11,1:187,2:187,5:187,4:18,6:18},
 224:{3:187,4:187,6:187,2:225,1:189,5:189},
 225:{2:21,3:224,4:224,5:224,1:226,6:226},
 226:{3:225,2:1012,1:194,4:194,5:194,6:194},
 227:{2:189,3:189,4:228,5:228,1:193,6:193},
 228:{1:227,2:227,3:227,4:190,6:190,5:144},
 223:{4:19,3:1009,6:1009,1:190,2:190,5:190},
 229:{3:86,4:86,2:35,5:35,6:36,1:1019},
 230:{1:41,2:1019,3:1019,4:1017,5:1017,6:96},
}
for n in NAV:
    E={e for e in E if n not in e}
for n,ex in NAV.items():
    N[n]['kind']='nav'; N[n]['exits']={str(k):v for k,v in ex.items()}
    for v in set(ex.values()):
        if (n,v) in ((227,228),(228,227)): continue
        add(n,v)
N[227]['orbit']=True; N[229]['orbit']=True
N[227]['jump']=228; N[228]['jump']=227
# --- asteroid lattice
lat_old=[1024,1026,1027,1030,1031,1032,1034,1035,1036,1037]
LAT=[212,169,99,207,166,53,213,57,211,168,52,102,106,105,61,60,217,218,216]
for i in lat_old: rm_node(i)
for i in LAT: E={e for e in E if i not in e}
O=(1300,2380)
def P(x,y): return (x+O[0],y+O[1])
rock1=new('asteroid',*P(170,255)); rock2=new('asteroid',*P(520,330)); rock3=new('asteroid',*P(640,265)); rock4=new('asteroid',*P(875,270))
dome1=new('scity',*P(405,125)); dome2=new('scity',*P(765,55))
A=dict(Aerie=212,rock1=rock1,B30=169,dome1=dome1,Y10=99,QT=207,dome2=dome2,B20=166,RD1=53,Airhome=213,R20=57,Qmid=211,B40=168,rock2=rock2,rock3=rock3,R10=52,rock4=rock4,Y20=102,YD1=106,YD2=105,R30=61,RD2=60,QB1=217,QB2=218,QB3=216)
L="""Aerie-rock1 Aerie-YD1 rock1-B30 rock1-R20 YD1-R20 YD1-QB1 B30-dome1 B30-Qmid R20-Qmid R20-YD2 QB1-YD2
dome1-Y10 dome1-B40 Qmid-B40 Qmid-rock2 YD2-rock2 YD2-QB2 Y10-QT B40-rock3 rock2-rock3 rock2-R30 QB2-R30
QT-dome2 rock3-R10 rock3-Y20 R30-Y20 R30-QB3 dome2-B20 R10-B20 R10-rock4 Y20-rock4 Y20-RD2 QB3-RD2
B20-RD1 rock4-RD1 rock4-Airhome RD2-Airhome
rock1-YD1 B30-R20 R20-QB1 dome1-Qmid Qmid-YD2 Y10-B40 B40-rock2 rock2-QB2 rock3-R30 dome2-R10 R10-Y20 Y20-QB3 B20-rock4 rock4-RD2 RD1-Airhome"""
for t in L.split():
    a,b=t.split('-'); add(A[a],A[b])
add(212,55); add(212,104); add(213,103)
# --- kinds of auto 'end' nodes
CITY=[1000,1006,1002,1001,1004,1008,1010,1011,1013,1015,1016,1020,1021,1022,1029,1038]
SCITY=[1007,1014,1017]
AST=[1003,1005,1009,1018,1019,1023,1033]
for i in CITY: N[i]['kind']='city'
for i in SCITY: N[i]['kind']='scity'
for i in AST: N[i]['kind']='asteroid'
N[1012]['kind']='base'
for i,n in N.items():
    if n['kind']=='end': print('UNCLASSIFIED end',i,n['x'],n['y'])
# oval values
VAL={120:10,8:10,70:10,125:10,0:30,110:30,3:30,121:30,7:30,64:30,92:10,42:10,45:10,160:10,163:10,47:10,36:20,50:20,101:10,174:10,
     169:30,99:10,168:40,52:10,166:20,57:20,102:20,61:30}
for i,v in VAL.items(): assert N[i]['kind']=='oval',i; N[i]['pen']=v
for i,n in N.items():
    if n['kind']=='oval': assert 'pen' in n,i
# drop isolated
deg={}
for a,b in E: deg[a]=deg.get(a,0)+1; deg[b]=deg.get(b,0)+1
for i in list(N):
    if deg.get(i,0)==0: print('isolated',i,N[i]['kind'],N[i]['x'],N[i]['y']); N.pop(i)
for i,n in N.items():
    if deg.get(i,0)==1 and n['kind'] not in('city',): print('deg1',i,n['kind'],n['x'],n['y'])
json.dump({'nodes':list(N.values()),'edges':sorted(E)},open('graph_final.json','w'))
print(len(N),len(E))
