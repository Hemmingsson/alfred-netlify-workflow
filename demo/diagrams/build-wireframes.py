#!/usr/bin/env python3
"""Build documentation wireframes from the shipped Alfred UI structure.

Source: workflow/sites.alfredui/{ui,components/*}.json and
Sources/NetlifyWindow/{SitePresenter,EmptyState}.swift.
Run from any directory: python3 demo/diagrams/build-wireframes.py.
"""
from pathlib import Path
from html import escape
from theme import theme_css

ROOT = Path(__file__).resolve().parents[2] / 'assets' / 'diagrams'
ROOT.mkdir(parents=True, exist_ok=True)
CSS = '''

svg{display:block;background:var(--sc-paper);color:var(--sc-ink);font-family:'SF Mono',ui-monospace,Menlo,monospace}
.well{fill:var(--sc-fill);stroke:var(--sc-ink);stroke-width:1.4}
.hug{fill:var(--sc-fill2);stroke:var(--sc-ink);stroke-width:1.1}
.slot{fill:none;stroke:var(--sc-muted);stroke-width:.8;stroke-dasharray:3 4;stroke-linecap:round}
.empty{fill:none;stroke:var(--sc-soft);stroke-width:.9;stroke-dasharray:7 5}
.thin{fill:none;stroke:var(--sc-ink);stroke-width:1}
.rel{fill:none;stroke:var(--sc-soft);stroke-width:.7;stroke-dasharray:4 5;stroke-linecap:round}
.lead{fill:none;stroke:var(--sc-soft);stroke-width:.8;stroke-linecap:round;stroke-linejoin:round}
.skeleton{fill:var(--sc-skeleton);stroke:none}
.action{fill:var(--sc-fill2);stroke:var(--sc-border);stroke-width:.8}
.actiontext{font-size:12px;fill:var(--sc-ink)}
.key{font-size:12px;fill:var(--sc-muted)}
.dt{font-size:12px;fill:var(--sc-ink);paint-order:stroke;stroke:var(--sc-paper);stroke-width:3px}
.sl{font:500 9px 'SF Mono',ui-monospace,Menlo,monospace;fill:var(--sc-muted);letter-spacing:.06em}
.message{font-size:19px;font-weight:600;fill:var(--sc-ink)}.detail{font-size:14px;fill:var(--sc-ink)}.button{font-size:13px;font-weight:600;fill:var(--sc-ink)}
.vt{font:500 17px 'SF Mono',ui-monospace,Menlo,monospace;fill:var(--sc-ink)}
'''

class Sheet:
    def __init__(self, height, trim=74):
        self.height = height - trim
        self.trim = trim
        self.parts = []
    def rect(self,x,y,w,h,cls='well',rx=5):
        self.parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" class="{cls}"/>')
    def text(self,x,y,text,cls='sl',anchor='start'):
        self.parts.append(f'<text x="{x}" y="{y}" class="{cls}" text-anchor="{anchor}">{escape(text)}</text>')
    def path(self,d,cls='thin'):
        self.parts.append(f'<path d="{d}" class="{cls}"/>')
    def slot(self,x,y,w,h,label,cls='slot'):
        self.rect(x,y,w,h,cls,3)
        self.text(x+w/2,y+h/2+3,label,'sl','middle')
    def callout(self,px,py,ex,ey,label,side=1):
        self.parts.append(f'<circle cx="{px}" cy="{py}" r="1.7" fill="var(--sc-ink)"/>')
        self.parts.append(f'<polyline points="{px},{py} {ex},{ey} {ex+side*8},{ey}" class="lead"/>')
        self.text(ex+side*12,ey+4,label,'dt','start' if side>0 else 'end')
    def save(self,slug,label):
        svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="{self.height}" viewBox="0 0 1200 {self.height}" role="img" aria-labelledby="title desc"><title id="title">{escape(label)}</title><desc id="desc">Documentation wireframe based on the shipped Alfred window. Dashed slots show flexible content; solid fills show controls and selection.</desc><style>{CSS}{theme_css()}</style><rect width="1200" height="{self.height}" fill="var(--sc-paper)"/>'+f'<g transform="translate(0 {-self.trim})">'+''.join(self.parts)+'</g></svg>\n'
        (ROOT/(slug+'.svg')).write_text(svg)
        html = f'<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{escape(label)}</title><style>html,body{{margin:0}}svg{{max-width:100%;height:auto}}</style></head><body><main>{svg}</main></body></html>\n'
        (ROOT/(slug+'.html')).write_text(html)

# Vector counterparts of the SF Symbols used by detail-pane.json.
# Paths keep symbols crisp in SVG, browser previews and PNG exports.
def icon(s,x,y,name,size=14):
    paths = {
        'chevron.left': '<path d="M15 4 L7 12 L15 20"/>',
        'chevron.right': '<path d="M9 4 L17 12 L9 20"/>',
        'arrow.clockwise': '<path d="M19 8 A8 8 0 1 0 20 14 M19 3 V8 H14"/>',
        'globe': '<circle cx="12" cy="12" r="9"/><ellipse cx="12" cy="12" rx="4" ry="9"/><path d="M3 12 H21 M5 7 H19 M5 17 H19"/>',
        'shippingbox': '<path d="M3 7 L12 2 L21 7 V17 L12 22 L3 17 Z M3 7 L12 12 L21 7 M12 12 V22 M7 4.8 L16 9.8"/>',
        'square.stack.3d.up': '<path d="M2 7 L12 2 L22 7 L12 12 Z M2 12 L12 17 L22 12 M2 17 L12 22 L22 17"/>',
        'text.bubble': '<path d="M3 3 H21 V17 H12 L7 22 V17 H3 Z M7 7 H17 M7 11 H15"/>',
        'person': '<circle cx="12" cy="6" r="4"/><path d="M3 22 V19 C3 11 21 11 21 19 V22 Z"/>',
        'arrow.triangle.branch': '<path d="M6 21 V4 M3 7 L6 3 L9 7 M6 15 C6 10 18 14 18 7 V3 M15 6 L18 2 L21 6"/>',
    }
    s.parts.append(f'<g transform="translate({x} {y}) scale({size/24})" fill="none" stroke="var(--sc-muted)" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">{paths[name]}</g>')

def browser_bar(s,x,y,w):
    s.rect(x,y,w,30,'well',0)
    for dx,name in [(7,'chevron.left'),(27,'chevron.right'),(47,'arrow.clockwise')]:
        icon(s,x+dx,y+8,name)
    icon(s,x+71,y+8,'globe')
    s.slot(x+91,y+6,w-102,18,'ADDRESS')

def picture(s,x,y,w,h,label='PICTURE'):
    s.rect(x,y,w,h,'well',0)
    s.path(f'M{x+12},{y+12} L{x+w-12},{y+h-12} M{x+w-12},{y+12} L{x+12},{y+h-12}','rel')
    if label:
        s.rect(x+w/2-94,y+h/2-13,188,26,'hug',3)
        s.text(x+w/2,y+h/2+3,label,'sl','middle')

s=Sheet(605)
x,y,w,h=180,104,840,477
split=x+305
s.rect(x,y,w,h,'thin',8)
s.path(f'M{split},{y} V{y+h}','thin')
s.slot(x+12,y+12,281,36,'SEARCH','well')
for i in range(5):
    ry=y+60+i*64
    s.rect(x+12,ry,281,57,'hug' if i==0 else 'well',6)
    s.slot(x+20,ry+9,57,36,'')
    if i == 0:
        s.parts.append(f'<text x="{x+48.5}" y="{ry+30}" class="sl" text-anchor="middle" style="font-size:8px;letter-spacing:0">Thumbnail</text>')
    if i == 0:
        s.text(x+87,ry+23,'Site name','actiontext')
        s.text(x+103,ry+42,'Repository','actiontext')
        s.text(x+280,ry+23,'3 h ago','sl','end')
    else:
        s.rect(x+87,ry+14,112 if i%2 else 136,7,'skeleton',3)
        s.rect(x+103,ry+34,88,5,'skeleton',2)
        s.rect(x+244,ry+14,36,5,'skeleton',2)
    s.rect(x+87,ry+32,10,10,'hug',2)
    if i == 1: s.text(x+280,ry+43,'Building','sl','end')
s.text(x+12,y+h-17,'12 sites · updated just now','sl')
s.text(x+293,y+h-17,'Refresh  ⌘R','sl','end')
dx=split+12;dw=w-329
browser_bar(s,dx,y+12,dw)
picture(s,dx,y+42,dw,257,label=None)

my=y+314
s.text(dx,my,'PROJECT','sl');s.text(dx+dw/2+10,my,'LATEST DEPLOY','sl')
for i,label in enumerate(['NAME / SOURCE','STACK / FORMS','DOMAINS / WARNINGS']):
    icon(s,dx,my+11+i*23,['shippingbox','square.stack.3d.up','globe'][i],12)
    s.slot(dx+21,my+10+i*23,dw/2-31,17,label)
for i,label in enumerate(['MESSAGE / STATE','COMMITTER / TIME','BRANCH / COMMIT']):
    icon(s,dx+dw/2+10,my+11+i*23,['text.bubble','person','arrow.triangle.branch'][i],12)
    s.slot(dx+dw/2+31,my+10+i*23,dw/2-31,17,label)
for offset,bw,label,key in [(63,126,'Copy URL','⌥↩'),(197,184,'Netlify Project','⌘↩'),(389,122,'Open Site','↩')]:
    s.rect(dx+offset,y+h-35,bw,25,'action',6)
    s.text(dx+offset+10,y+h-18,label,'actiontext')
    s.text(dx+offset+bw-9,y+h-18,key,'key','end')
s.callout(x+14,y+88,159,y+100,'Selected site',-1)
s.callout(x+100,y+h-23,159,y+h-6,'Cache status',-1)
s.callout(dx+dw-8,y+27,1040,y+27,'Navigation')
s.callout(dx+dw-8,y+180,1040,y+190,'Site preview')
s.callout(dx+dw-8,y+h-22,1040,y+h-8,'Window actions')
s.save('site-browser-elements','Site browser elements and relations')

s=Sheet(431)
for i,(title,note) in enumerate([('Live page','Framing allowed; page loaded'),('Picture fallback','Framing refused, pending or demo'),('No preview','Never published or no site URL')]):
    xx=24+i*393
    s.text(xx,98,title,'vt');s.text(xx,118,note,'sl')
    browser_bar(s,xx,132,366)
    if i==0:
        s.rect(xx,162,366,205,'well',0)
        s.slot(xx+15,177,336,24,'PAGE HEADER')
        s.slot(xx+15,216,205,99,'PAGE CONTENT')
        s.slot(xx+235,216,116,99,'CONTENT')
        s.text(xx+183,349,'DESKTOP WEB PAGE','sl','middle')
    elif i==1: picture(s,xx,162,366,205,label=None)
    else:
        s.rect(xx,162,366,205,'empty',0)
        s.text(xx+183,270,'No published page','sl','middle')
    s.slot(xx,384,366,23,'PROJECT + DEPLOY DETAILS')
s.save('site-browser-variants','Preview variants')

s=Sheet(290, trim=0)
# Empty-state variations retain the actual window's outer layout, not the split.
for i,(title,kind) in enumerate([('Signed out','sign-in'),('Connecting','connecting'),('First refresh failed','retry')]):
    xx=24+i*393
    s.text(xx,24,title,'vt')
    s.rect(xx,41,366,226,'thin',6)
    s.slot(xx+47,102,272,24,'MESSAGE')
    s.slot(xx+47,137,272,18,'DETAIL')
    if kind=='connecting':
        s.slot(xx+74,185,110,25,'TRY AGAIN','action')
        s.slot(xx+194,185,98,25,'CANCEL','action')
    else:
        s.slot(xx+103,185,160,25,('SIGN IN' if kind=='sign-in' else 'RETRY')+'','action')
s.save('account-states','Account states')
