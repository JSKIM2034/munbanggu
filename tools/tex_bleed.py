# UV 섬 바깥(빈 틈)을 가장 가까운 섬의 색으로 채워서, 줄인 텍스처에서 검은 금이 비치지 않게 해요.
# rig_kid2.py / prop_export.py 안에서 import해서 써요.
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

def bleed(img, mesh):
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    uv = mesh.data.uv_layers.active.data
    for poly in mesh.data.polygons:
        pts = [(uv[li].uv[0] * w, (1.0 - uv[li].uv[1]) * h) for li in poly.loop_indices]
        d.polygon(pts, fill=255, outline=255)
    m = np.array(mask)[::-1] > 0          # 블렌더 픽셀은 아래쪽부터
    m = ndimage.binary_dilation(m, iterations=1)
    _, (iy, ix) = ndimage.distance_transform_edt(~m, return_indices=True)
    out = px[iy, ix]
    img.pixels[:] = out.ravel()
    print("BLEED", int(m.sum()), "of", w * h)
