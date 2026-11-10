import numpy as np, cv2, json
im=cv2.imread('board.png')[:,:,::-1].astype(int)
R,G,B=im[...,0],im[...,1],im[...,2]
mx=im.max(2); mn=im.min(2)
masks={
 'red':(R>200)&(G<90)&(B<90),
 'yellow':(R>215)&(G>185)&(B<90),
 'blue':(abs(R-61)<35)&(abs(G-176)<35)&(abs(B-207)<35),
 'box':(R>120)&(R<200)&(G>230)&(B>230),
 'nav':(R<90)&(G>200)&(B>210),
}
nodes=[]
for name,m in masks.items():
    m8=m.astype(np.uint8)
    if name in('red','yellow','blue'):
        m8=cv2.morphologyEx(m8,cv2.MORPH_CLOSE,np.ones((5,5),np.uint8))
    n,lab,st,cen=cv2.connectedComponentsWithStats(m8,8)
    for i in range(1,n):
        x,y,w,h,a=st[i]
        if a<150: continue
        kind=name
        if name in('red','yellow','blue'):
            if w>60 and w>1.4*h: kind='oval'
            elif 18<w<62 and 18<h<62 and a>0.55*w*h: kind='dot'
            else: continue
        elif name=='box':
            if not(50<w<110 and 50<h<110): continue
        elif name=='nav':
            if a<3000: continue
        nodes.append({'kind':kind,'color':name if name in('red','yellow','blue') else None,'x':int(cen[i][0]),'y':int(cen[i][1]),'w':int(w),'h':int(h),'a':int(a),'bbox':[int(x),int(y),int(w),int(h)]})
from collections import Counter
print(Counter((n['kind'],n['color']) for n in nodes))
json.dump(nodes,open('det_nodes.json','w'))
