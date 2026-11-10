import json,cv2,sys
g=json.load(open(sys.argv[1]))
nodes={n['id']:n for n in g['nodes']}
im=cv2.imread('board.png')
for a,b in g['edges']:
    A,B=nodes[a],nodes[b]; cv2.line(im,(A['x'],A['y']),(B['x'],B['y']),(0,255,0),5)
C={'dot':(255,0,255),'oval':(0,255,0),'box':(0,128,255),'nav':(255,255,0),'end':(0,0,255)}
for n in nodes.values():
    c=C.get(n['kind'],(0,200,255))
    cv2.circle(im,(n['x'],n['y']),10,c,-1)
    t=str(n['id'])+(n.get('tag','') and ':'+n['tag'])
    cv2.putText(im,t,(n['x']+10,n['y']-10),cv2.FONT_HERSHEY_SIMPLEX,0.9,(0,0,0),6)
    cv2.putText(im,t,(n['x']+10,n['y']-10),cv2.FONT_HERSHEY_SIMPLEX,0.9,(255,255,255),2)
H,W=im.shape[:2]
for ty in range(3):
    for tx in range(3):
        x0,y0=tx*W//3,ty*H//3
        cv2.imwrite(f'view/t_{ty}{tx}.jpg',im[max(0,y0-80):y0+H//3+80, max(0,x0-80):x0+W//3+80],[cv2.IMWRITE_JPEG_QUALITY,75])
