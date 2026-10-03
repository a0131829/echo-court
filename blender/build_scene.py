"""Echo Court II: three original, pastel spatial puzzle dioramas.
One authored level specification drives both Blender geometry and Godot navigation.
Run: blender --background --python blender/build_scene.py
"""
import bpy, math, os, json, random
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PALETTE={'cream':'FDF9F0','mint':'D2F1E1','blue':'C1DEE8','pink':'F5BCBD','lavender':'E1D5EF','butter':'F2E5C1','cocoa':'674D5B','peach':'FAEADA'}

def linear(v):return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4

def material(name,code,metallic=0):
    rgb=tuple(int(code[i:i+2],16)/255 for i in (0,2,4))
    rgb=tuple(linear(v) for v in rgb)
    m=bpy.data.materials.new(name);m.diffuse_color=(*rgb,1);m.use_nodes=True
    m.node_tree.nodes.clear();p=m.node_tree.nodes.new('ShaderNodeBsdfPrincipled');out=m.node_tree.nodes.new('ShaderNodeOutputMaterial')
    m.node_tree.links.new(p.outputs['BSDF'],out.inputs['Surface'])
    p.inputs['Base Color'].default_value=(*rgb,1);p.inputs['Roughness'].default_value=.83;p.inputs['Metallic'].default_value=metallic
    return m

bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
M={k:material(k,v) for k,v in PALETTE.items()}
M['shadow']=material('muted plum recess','AC95B6')
M['leaf']=material('mint leaf shadow','91BCAE')
M['brass']=material('honey brass','CDA668',.15)
M['scarf']=material('rose scarf','C77F9C')

# All design coordinates are Godot X,Y(up),Z. Blender exports them without guesswork.
def xyz(v):return(v[0],-v[2],v[1])
def finish(o,name,mat):o.name=name;o.data.materials.append(M[mat] if isinstance(mat,str) else mat);return o
def box(name,p,s,mat,bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(p));o=bpy.context.object;o.dimensions=(s[0],s[2],s[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('soft bevel','BEVEL');mod.width=bevel;mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(o,name,mat)
def cyl(name,p,r,h,mat,n=32,r2=None):
    bpy.ops.mesh.primitive_cone_add(vertices=n,radius1=r,radius2=r if r2 is None else r2,depth=h,location=xyz(p));return finish(bpy.context.object,name,mat)
def ball(name,p,r,mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,radius=r,location=xyz(p));return finish(bpy.context.object,name,mat)
def ring(name,p,r,thick,mat):
    bpy.ops.mesh.primitive_torus_add(major_segments=48,minor_segments=8,location=xyz(p),major_radius=r,minor_radius=thick);return finish(bpy.context.object,name,mat)
def arch(name,x,z,y,width,height,depth,mat):
    r=width/2;t=.20;spring=y+height-r
    box(name+' left',(x-r-t/2,(y+spring)/2,z),(t,spring-y,depth),mat)
    box(name+' right',(x+r+t/2,(y+spring)/2,z),(t,spring-y,depth),mat)
    verts=[];faces=[];steps=20
    for i in range(steps+1):
        a=math.pi*i/steps
        for radius,dz in [(r,-depth/2),(r+t,-depth/2),(r,depth/2),(r+t,depth/2)]:verts.append(xyz((x+math.cos(a)*radius,spring+math.sin(a)*radius,z+dz)))
    for i in range(steps):
        k=i*4;n=k+4;faces.extend([(k,n,n+1,k+1),(k+2,k+3,n+3,n+2),(k,k+2,n+2,n),(k+1,n+1,n+3,k+3)])
    faces.extend([(0,1,3,2),(steps*4,steps*4+2,steps*4+3,steps*4+1)])
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);finish(o,name,mat)
def export(name,objects=None):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects or list(bpy.context.scene.objects):o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'assets',name+'.glb'),export_format='GLB',use_selection=True,export_yup=True)
def clear():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def save(name):bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'blender',name+'.blend'))

# Each island has different foundation depth, roof silhouette and visual purpose.
def island(id,p,style,tint,index):
    x,y,z=p;bottom=-.6-(index%3)*.55
    width=2.05
    box(id+' shaft',(x,(bottom+y-.3)/2,z),(1.84,y-.3-bottom,1.84),tint,.045)
    box(id+' plinth',(x,bottom+.08,z),(2.0,.18,2.0),'cream')
    box(id+' cornice',(x,y-.20,z),(2.20,.24,2.20),'cream')
    box(id+' roof tile',(x,y-.055,z),(2.08,.11,2.08),'cream',.015)
    for dz in [-.9,.9]:box(id+' roof line',(x,y+.007,z+dz),(1.84,.014,.018),'brass',.002)
    # Front and right reliefs, varying with the height of the building.
    levels=max(1,int((y-bottom-1)/1.8))
    for j in range(levels):
        wy=bottom+.5+j*1.65
        box(id+' inset',(x,wy+.4,z+.928),(.62,.88,.023),'shadow',.06)
        arch(id+' blind arch',x,z+.958,wy-.04,.48,1.03,.045,'cream')
        box(id+' right inset',(x+.928,wy+.42,z-.13),(.024,.88,.53),'shadow',.045)
    for dx in [-.68,.68]:box(id+' pilaster',(x+dx,(bottom+y-.35)/2,z+.94),(.065,y-.35-bottom,.045),'cream',.008)
    if style=='garden':
        for dx,dz,r,h in [(-.65,-.63,.26,1.0),(.63,-.66,.19,.7)]:
            box(id+' pot',(x+dx,y+.11,z+dz),(.42,.22,.42),'pink')
            cyl(id+' stem',(x+dx,y+.38,z+dz),.04,.52,'brass',10)
            cyl(id+' cypress',(x+dx,y+.67,z+dz),r,h,'leaf',12,0)
        box(id+' bench',(x-.68,y+.13,z+.42),(.27,.26,.69),'mint')
    elif style in ('temple','exit'):
        height=2.15 if style=='temple' else 2.7
        arch(id+' open portal',x,z-.54,y,1.04,height,.31,tint)
        box(id+' canopy',(x,y+height+.12,z-.54),(1.76,.18,.68),'cream')
        box(id+' cornice step',(x,y+height+.28,z-.54),(1.47,.14,.52),tint)
        if style=='temple':
            # A small dome establishes a different silhouette from the exit.
            dome=ball(id+' dome',(x,y+height+.31,z-.54),.46,'lavender');dome.scale.z=.65
            cyl(id+' dome pin',(x,y+height+.85,z-.54),.065,.3,'brass',12,0)
        else:
            ball(id+' pearl',(x,y+height+.59,z-.54),.13,'butter')
    elif style=='observatory':
        for dx in [-.72,.72]:
            cyl(id+' column',(x+dx,y+.75,z-.55),.09,1.5,'cream')
            cyl(id+' column capital',(x+dx,y+1.46,z-.55),.15,.12,tint)
        box(id+' top beam',(x,y+1.65,z-.55),(1.85,.24,.61),tint)
        orb=ball(id+' cosmic globe',(x,y+2.12,z-.55),.38,'lavender')
        rr=ring(id+' orbit',(x,y+2.1,z-.55),.57,.035,'brass');rr.rotation_euler.x=.35
    elif style=='start':
        for dx in [-.71,.71]:
            cyl(id+' lamp foot',(x+dx,y+.12,z+.60),.085,.24,'brass')
            ball(id+' lamp',(x+dx,y+.31,z+.60),.115,'butter')
        # Ornamental steps toward the foreground, distinct from navigable stairs.
        for k in range(6):box(id+' arrival step',(x,y-.17-k*.19,z+1.16+k*.22),(.92,.2,.25),'cream',.012)
    elif style=='switch':
        cyl(id+' switch pedestal',(x-.64,y+.18,z-.58),.2,.36,'lavender',8)
        ball(id+' switch jewel',(x-.64,y+.46,z-.58),.15,'blue')
    elif style=='balcony':
        for k in [-.91,-.51,.51,.91]:cyl(id+' baluster',(x+k,y+.3,z-.83),.044,.6,'cream',12)
        for k in [-.71,.71]:box(id+' balustrade',(x+k,y+.63,z-.83),(.48,.09,.10),tint)
    # Small suspended satellite stones rather than identical flat foundations.
    if index%2==0:
        ob=box(id+' fragment',(x+.72,bottom-.64,z+.23),(.16,.22,.16),tint);ob.rotation_euler=(.2,.1,.4)


def stair(level,a,b,tint='pink'):
    """Build literal steps and their exact movement nodes. No floating ramp path."""
    p=Vector(level['nodes'][a]['p']);q=Vector(level['nodes'][b]['p']);delta=q-p
    axis=Vector((delta.x,0,delta.z)).normalized();dist=Vector((delta.x,0,delta.z)).length
    start=p+axis*1.04;end=q-axis*1.04
    run=dist-2.08;n=max(7,math.ceil(abs(delta.y)/.19))
    prev=a
    # Landing-edge point removes diagonal sliding up from the island centre.
    edge_id=a+'__'+b+'_edge';level['nodes'][edge_id]={'p':list(start),'hidden':True};level['edges'].append([a,edge_id]);prev=edge_id
    for i in range(n):
        u=(i+.5)/n;pt=start.lerp(end,u);pt.y=p.y+delta.y*(i+1)/n
        sx=run/n+.01 if abs(axis.x)>.5 else 1.0;sz=1.0 if abs(axis.x)>.5 else run/n+.01
        box('Stair '+a+' '+str(i),(pt.x,pt.y-.10,pt.z),(sx,.20,sz),'cream',.008)
        # continuous side stringers beneath tread blocks
        for side in [-1,1]:
            off=Vector((-axis.z,0,axis.x))*side*.52
            box('Stair edge '+a,(pt.x+off.x,pt.y-.18,pt.z+off.z),(sx if abs(axis.x)>.5 else .06,.21,sz if abs(axis.z)>.5 else .06),tint,.008)
        key=a+'__'+b+'_'+str(i);level['nodes'][key]={'p':list(pt),'hidden':True};level['edges'].append([prev,key]);prev=key
    level['edges'].append([prev,b])


def level_base(title,subtitle,bg,focus,size):
    return {'title':title,'subtitle':subtitle,'background':bg,'focus':focus,'camera_size':size,'nodes':{},'edges':[],'rotors':[],'collectibles':{},'stairs':[],'exit':'exit','start':'start','lift':None,'gated_edges':[]}
def node(l,id,p,style='balcony',tint='mint',name=None):l['nodes'][id]={'p':p,'style':style,'tint':tint,'name':name or id}
def rotor(l,id,p,ports,tint='pink'):
    l['rotors'].append({'id':id,'p':p,'ports':ports,'orientation':0,'tint':tint})
def stamp(l,id,label,color):l['collectibles'][id]={'label':label,'color':PALETTE[color]}

levels=[]
l=level_base('薄荷回廊','循著階梯，把第一縷微光帶回庭院。','ECE8F0',[-.5,2,-1.3],18.7)
node(l,'start',[0,2,4.2],'start','blue','來時階');node(l,'west',[-4.2,2,0],'balcony','mint','薄荷露台')
node(l,'garden',[-4.2,3.8,-3.6],'garden','mint','高處花園');node(l,'north',[0,2,-4.2],'balcony','pink','薔薇廊')
node(l,'moon',[0,4,-7.8],'temple','lavender','月影亭');node(l,'exit',[4.2,2,0],'exit','peach','歸途之門')
rotor(l,'dial',[0,2,0],['west','start','exit','north'])
l['stairs']=[['west','garden'],['north','moon']];stamp(l,'garden','薄荷','mint');stamp(l,'moon','月光','lavender')
l['solution']=[['walk','garden'],['walk','dial'],['turn',-1],['walk','moon'],['walk','dial'],['turn',-1],['walk','exit']]
levels.append(l)

l=level_base('糖霜天梯','喚醒升降台，去屋頂尋找星光。','E7EEF0',[.3,2.6,-2.8],22.3)
node(l,'start',[0,2,4.2],'start','pink','來時階');node(l,'west',[-4.2,2,0],'balcony','blue','水藍廊')
node(l,'key',[-4.2,3.6,-3.6],'switch','mint','風鈴花園');node(l,'north',[0,2,-4.2],'balcony','lavender','升降台下站')
node(l,'roof',[0,5,-8.4],'balcony','blue','雲上露台');node(l,'star',[3.6,6.5,-8.4],'observatory','lavender','星糖觀測台')
node(l,'east',[4.2,2,0],'garden','pink','草莓花園');node(l,'exit',[7.8,3.6,0],'exit','peach','歸途之門')
rotor(l,'dial',[0,2,0],['west','start','east','north'],'mint')
l['stairs']=[['west','key'],['roof','star'],['east','exit']]
l['lift']={'id':'lift','p':[0,2,-6.3],'height':5,'lower':'north','upper':'roof','key':'key'}
stamp(l,'key','風鈴','mint');stamp(l,'roof','雲朵','blue');stamp(l,'star','星光','lavender')
l['solution']=[['walk','key'],['walk','dial'],['turn',-1],['walk','lift'],['lift'],['walk','star'],['walk','lift'],['lift'],['walk','dial'],['turn',-1],['walk','exit']]
levels.append(l)

l=level_base('雙庭星環','兩座庭院，四枚微光，一條歸途。','F1E5E9',[0,2.7,-2.0],25.4)
node(l,'start',[-4.2,2,5.2],'start','blue','低庭入口');node(l,'west',[-8.4,2,1],'balcony','mint','薄荷廊')
node(l,'garden',[-8.4,3.6,-2.6],'garden','mint','風之花園');node(l,'switch',[-4.2,2,-3.2],'switch','blue','天階開關')
node(l,'transfer',[0,2,1],'balcony','pink','天階下站');node(l,'upper_west',[0,5,-3.2],'balcony','lavender','天階上站')
node(l,'upper_south',[4.2,5,1],'garden','pink','雲中花園');node(l,'upper_north',[4.2,5,-7.4],'balcony','blue','觀星回廊')
node(l,'star',[4.2,7,-11],'observatory','lavender','最高的星台');node(l,'exit',[8.4,5,-3.2],'exit','peach','歸途之門')
rotor(l,'lower_dial',[-4.2,2,1],['west','start','transfer','switch'],'mint')
rotor(l,'upper_dial',[4.2,5,-3.2],['upper_west','upper_south','exit','upper_north'],'lavender')
l['stairs']=[['west','garden'],['transfer','upper_west'],['upper_north','star']]
l['gate']={'a':'transfer','b':'upper_west','key':'switch'}
stamp(l,'garden','風','mint');stamp(l,'switch','鈴','blue');stamp(l,'upper_south','花','pink');stamp(l,'star','星','lavender')
l['solution']=[['walk','garden'],['walk','lower_dial'],['turn',-1],['walk','switch'],['walk','lower_dial'],['turn',-1],['walk','upper_south'],['walk','upper_dial'],['turn',-1],['walk','star'],['walk','upper_dial'],['turn',-1],['walk','exit']]
levels.append(l)

for idx,l in enumerate(levels):
    clear()
    for j,(id,nd) in enumerate(l['nodes'].items()):island(id,nd['p'],nd['style'],nd['tint'],j)
    for a,b in l['stairs']:
        edge_start=len(l['edges']);stair(l,a,b,l['nodes'][a]['tint'])
        if l.get('gate',{}).get('a')==a:l['gated_edges']=[l['edges'][edge_start]]
    for r in l['rotors']:
        x,y,z=r['p'];bottom=-.75
        cyl(r['id']+' foot',(x,bottom,z),.68,.3,r['tint'],12)
        cyl(r['id']+' column',(x,(bottom+y-.35)/2,z),.44,y-.35-bottom,r['tint'],12)
        for h in [bottom+.2,y-.6]:cyl('spindle bracelet',(x,h,z),.5,.11,'brass')
        cyl('spindle capital',(x,y-.23,z),.76,.28,'cream',12)
    if l['lift']:
        x,y,z=l['lift']['p'];top=l['lift']['height']
        # Two slender rails and a visible counterweight tower, open in front.
        for dx in [-.84,.84]:
            box('lift rail',(x+dx,(y+top)/2,z-.38),(.11,top-y+1.3,.13),'lavender')
            cyl('lift cable',(x+dx*.8,(y+top)/2,z-.39),.025,top-y+.8,'brass',12)
        box('lift head',(x,top+.68,z-.38),(1.93,.19,.43),'cream')
        for yy,zz in [(y,z+1.0),(top,z-1.0)]:box('lift gangway',(x,yy-.09,zz),(.92,.18,.62),'cream')
    # Decorative disconnected mini-tower, visibly distinct from playable platforms.
    if idx>0:
        xx,zz=(-6.9,3.7) if idx==1 else (8.0,3.3)
        cyl('satellite tower',(xx,.3,zz),.36,2,'lavender',12)
        cyl('satellite roof',(xx,1.6,zz),.48,.7,'pink',12,0)
        ring('satellite halo',(xx,-1,zz),.65,.026,'brass')
    export('court_'+str(idx+1));save('architecture_'+str(idx+1))

# Shared turntable modules, each using an actual sampled palette color.
for tint in ['pink','mint','lavender']:
    clear()
    # Keep the structural top (-.030) below the marble bottom (-.024).
    # Coplanar tops at y=0 caused alternating cream/tint depth flicker in motion.
    box('West bridge',(-1.61,-.21,0),(3.22,.36,.99),tint)
    box('South bridge',(0,-.21,1.61),(.99,.36,3.22),tint)
    box('West marble',(-1.6,-.012,0),(3.2,.024,.9),'cream',.009)
    box('South marble',(0,-.012,1.6),(.9,.024,3.2),'cream',.009)
    cyl('Disc rim',(0,.035,0),.70,.07,'brass',48);cyl('Disc inlay',(0,.076,0),.59,.016,tint,48)
    ring('Disc fine line',(0,.088,0),.47,.013,'cream')
    for k in range(8):
        a=k*math.tau/8;cyl('Disc stud',(math.cos(a)*.64,.078,math.sin(a)*.64),.021,.025,'cream',12)
    for d in [1.4,2.8]:
        box('Walking joint',(-d,.008,0),(.02,.016,.88),'brass',.001);box('Walking joint',(0,.008,d),(.88,.016,.02),'brass',.001)
    export('bridge_'+tint);save('bridge_'+tint)
clear()
box('Lift platform',(0,-.14,0),(1.5,.28,1.5),'lavender');box('Lift marble',(0,.0,0),(1.38,.045,1.38),'cream')
ring('Lift rune',(0,.035,0),.40,.025,'brass')
for dx in [-.67,.67]:
    cyl('Lift corner',(dx,.20,-.58),.045,.4,'brass',12)
    ball('Lift pearl',(dx,.44,-.58),.066,'butter')
export('lift');save('lift')
clear()
cyl('Traveler robe',(0,.25,0),.20,.50,'cream',12,.085);ball('Traveler head',(0,.61,0),.14,'cream')
cyl('Traveler hat',(0,.80,0),.18,.26,'cocoa',12,0);box('Traveler face',(0,.615,.12),(.15,.095,.036),'cocoa',.012)
for x in [-.045,.045]:ball('Traveler eye',(x,.627,.141),.012,'butter')
box('Traveler scarf',(0,.49,.12),(.23,.07,.12),'scarf')
for x in [-.075,.075]:ball('Traveler foot',(x,.035,.045),.055,'cocoa')
export('traveler');save('traveler')
# Keep the editable chapter sources fully assembled, while exported GLBs stay modular.
def append_source(source,collection,offset):
    with bpy.data.libraries.load(os.path.join(ROOT,'blender',source+'.blend')) as (src,dst):dst.objects=src.objects
    coll=bpy.data.collections.new(collection);bpy.context.scene.collection.children.link(coll)
    for ob in dst.objects:
        if ob:
            coll.objects.link(ob);ob.location+=Vector(xyz(offset))
clear();save('_assembly')
for idx,l in enumerate(levels):
    clear()
    append_source('architecture_'+str(idx+1),'Architecture',[0,0,0])
    for r in l['rotors']:append_source('bridge_'+r['tint'],r['id'],r['p'])
    if l['lift']:append_source('lift','Lift',l['lift']['p'])
    append_source('traveler','Traveler',l['nodes'][l['start']]['p'])
    save('court_'+str(idx+1))
# Pack an overview of all editable architecture into one source file.
clear();save('_assembly')
for idx in range(3):
    with bpy.data.libraries.load(os.path.join(ROOT,'blender','court_'+str(idx+1)+'.blend')) as (src,dst):dst.objects=src.objects
    coll=bpy.data.collections.new('Chapter '+str(idx+1));bpy.context.scene.collection.children.link(coll)
    for o in dst.objects:
        if o:coll.objects.link(o);o.location.x+=idx*26
save('echo_court')
with open(os.path.join(ROOT,'assets','levels.json'),'w') as f:json.dump({'palette':PALETTE,'levels':levels},f,ensure_ascii=False,indent=2)
for filename in ['_assembly.blend','_assembly.blend1']:
    path=os.path.join(ROOT,'blender',filename)
    if os.path.exists(path):os.remove(path)
print('THREE_CHAPTERS_EXPORTED')
