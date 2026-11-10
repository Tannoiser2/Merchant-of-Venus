import numpy as np, cv2, json
from skimage.morphology import skeletonize
im=cv2.imread('board.png')[:,:,::-1].astype(int)
mx=im.max(2); mn=im.min(2)
gray=((mx-mn<25)&(mn>160)&(mx<240)).astype(np.uint8)
gray=cv2.morphologyEx(gray,cv2.MORPH_OPEN,np.ones((3,3),np.uint8))
nodes=json.load(open('det_nodes.json'))
H,W=gray.shape
lab=np.zeros((H,W),np.int32)  # node id+1 touch map
for n in nodes:
    x,y,w,h=n['bbox']; p=10 if n['kind']!='nav' else 14
    if n['kind']=='nav':
        # use actual nav mask region
        pass
    lab[max(0,y-p):y+h+p, max(0,x-p):x+w+p]=n['id']+1
# nav: refine with mask dilation
R,G,B=im[...,0],im[...,1],im[...,2]
nav=((R<90)&(G>200)&(B>210)).astype(np.uint8)
navd=cv2.dilate(nav,np.ones((25,25),np.uint8))
n_,nl=cv2.connectedComponents(navd)
for n in nodes:
    if n['kind']=='nav':
        l=nl[n['y'],n['x']]
        if l: lab[nl==l]=n['id']+1
path=gray.copy(); path[lab>0]=0
path=cv2.morphologyEx(path,cv2.MORPH_CLOSE,np.ones((5,5),np.uint8))
path[lab>0]=0
nc,cl,st,_=cv2.connectedComponentsWithStats(path,8)
touchmap=cv2.dilate((lab>0).astype(np.uint8),np.ones((9,9),np.uint8))
labd=cv2.dilate(lab.astype(np.float32),np.ones((9,9),np.uint8)).astype(np.int32)
segs=[]
for i in range(1,nc):
    if st[i][4]<60: continue
    bx,by,bw,bh=st[i][:4]; P=12
    x0,y0=max(0,bx-P),max(0,by-P); x1,y1=min(W,bx+bw+P),min(H,by+bh+P)
    comp=(cl[y0:y1,x0:x1]==i)
    L=labd[y0:y1,x0:x1]; Lr=lab[y0:y1,x0:x1]
    compd=cv2.dilate(comp.astype(np.uint8),np.ones((7,7),np.uint8))>0
    ids={int(j)-1 for j in np.unique(Lr[compd & (Lr>0)])}
    sk=skeletonize(comp)
    ys,xs=np.nonzero(sk)
    # endpoints
    k=cv2.filter2D(sk.astype(np.uint8),-1,np.ones((3,3)))
    ends=[(int(x+x0),int(y+y0)) for x,y in zip(xs,ys) if k[y,x]==2]
    ends=[e for e in ends if lab[max(0,e[1]-22):e[1]+22, max(0,e[0]-22):e[0]+22].max()==0]
    segs.append({'nodes':sorted(ids),'ends':ends,'len':int(sk.sum()),'bbox':[int(v) for v in st[i][:4]]})
json.dump(segs,open('segs.json','w'))
from collections import Counter
print(len(segs), Counter((len(s['nodes']),len(s['ends'])) for s in segs))
