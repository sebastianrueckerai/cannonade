#!/usr/bin/env python3
"""Convert the Unity prefabs of Grid Cannons into Godot .tscn scenes.

Usage: python3 godot/tools/unity2godot.py   (run from the repository root)

What it does:
  * Unity materials (Assets/Materials/*.mat) -> godot/materials/*.tres (albedo colour)
  * Unity prefabs (Assets/Prefabs/*.prefab)  -> godot/prefabs/*.tscn
      - GameObjects become Node3D, built-in meshes become MeshInstance3D with
        Box/Cylinder/Sphere meshes of the same size as Unity's primitives.
      - Every MonoBehaviour becomes a child component Node named after the
        script, using res://scripts/components/<Script>.gd, with its serialized
        fields converted (numbers, colours, hex encoded arrays, references to
        nodes inside the prefab and to other prefabs).
      - Nested prefab instances become instanced sub scenes.
  * Wall model prefabs (Assets/Prefabs/WallModells) wrap the imported FBX
    models, normalised to a 1x1 tile.

Coordinate conversion: Unity is left handed, Godot right handed. We mirror the
z axis (Unity z -> Godot -z). Positions become (x, y, -z) and rotations
(qx, qy, qz, qw) become (-qx, -qy, qz, qw).
"""
import glob
import math
import os
import re
import sys

import yaml

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ASSETS = os.path.join(REPO, 'Assets')
GODOT = os.path.join(REPO, 'godot')

# ---------------------------------------------------------------- guid lookup
GUID2PATH = {}
for meta in glob.glob(ASSETS + '/**/*.meta', recursive=True):
    with open(meta, errors='ignore') as f:
        for line in f:
            if line.startswith('guid:'):
                GUID2PATH[line.split()[1]] = meta[len(ASSETS) + 1:-5]
                break

BUILTIN_MESH = {'10202': 'Cube', '10206': 'Cylinder', '10207': 'Sphere', '10208': 'Capsule',
                '10209': 'Plane', '10210': 'Quad'}

# Field types that are serialized as hex strings in Unity YAML.
HEX_INT_FIELDS = {'signature', 'upgradeTypes'}
BOOL_FIELDS = {'turns', 'rotates', 'tileDestroyer', 'defaultForSize', 'on', 'resetting', 'useCustomCursor',
               'useRandomSeed', 'shootingAllowed', 'buildingAllowed'}
HEX_BOOL_FIELDS = {'accessColFromDownLeft', 'connectorsUpDownLeftRight'}
# Fields we never export (runtime state / unused).
SKIP_FIELDS = {'m_ObjectHideFlags', 'm_CorrespondingSourceObject', 'm_PrefabInstance', 'm_PrefabAsset',
               'm_GameObject', 'm_Enabled', 'm_EditorHideFlags', 'm_Script', 'm_Name',
               'm_EditorClassIdentifier', 'm_PrefabParentObject', 'm_PrefabInternal',
               'buildingPlace', 'player', 'map', 'game', 'nextWall', 'nextBuilding', 'buildableTileSelected',
               'startBase', 'wallTiles', 'ships', 'fleet', 'enemyPlayers', 'destinationTile', 'target',
               'upgradeSelection', 'supplyBar', 'supplyNeededBar', 'cursor', 'wallSpawn', 'buildingSpawn',
               'mainColor', 'highlightPosColor', 'highlightNegColor', 'percentFinished',
               'structure', 'wallStacked', 'idxX', 'idxZ', 'ship', 'commingShip', 'lineRendererPrefab',
               'enclosedColor', 'openColor', 'maxEnclosedColor', 'minEnclosedColor', 'maxOpenColor',
               'minOpenColor', 'enclosedColorMin', 'enclosedColorMax', 'openColorMin', 'openColorMax',
               'aimPoint', 'canBuildOnTile', 'freeTileSelected', 'canStackWall', 'canCombine', 'playerID',
               'controls', 'buildingBlock', 'cannonPrefab', 'upgradePrefabs', 'lastResetTime',
               'currentDamageAbsorb', 'secondsLastShot', 'secondsLastBuilding', 'nextBulletTime_',
               'burning', 'isWall', 'shaking', 'water'}


def parse_unity_yaml(path):
    """Returns {fileID: (classId, typeName, data_dict, stripped)}"""
    txt = open(path, errors='ignore').read()
    parts = re.split(r'^--- !u!(\d+) &(-?\d+)( stripped)?\s*$', txt, flags=re.M)
    objs = {}
    for i in range(1, len(parts), 4):
        cls, fid, stripped, body = parts[i], parts[i + 1], parts[i + 2], parts[i + 3]
        data = yaml.load(body, Loader=yaml.BaseLoader)
        (typ, d), = data.items()
        objs[fid] = (cls, typ, d or {}, bool(stripped))
    return objs


def ref_of(v):
    """Unity reference dict -> (fileID, guid or None)."""
    if isinstance(v, dict) and 'fileID' in v:
        return v['fileID'], v.get('guid')
    return None


def fvec(d, keys=('x', 'y', 'z')):
    return [float(d.get(k, 0)) for k in keys]


def quat_to_basis(q):
    x, y, z, w = q
    n = math.sqrt(x * x + y * y + z * z + w * w) or 1.0
    x, y, z, w = x / n, y / n, z / n, w / n
    return [
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ]


def g(v):
    s = ('%.6f' % v).rstrip('0').rstrip('.')
    return '0' if s in ('-0', '') else s


def transform_str(pos, rot, scale):
    """Unity local TRS -> Godot Transform3D string (with z mirroring)."""
    px, py, pz = pos
    qx, qy, qz, qw = rot
    b = quat_to_basis((-qx, -qy, qz, qw))
    sx, sy, sz = scale
    # basis columns scaled
    cols = [[b[r][c] * s for r in range(3)] for c, s in enumerate((sx, sy, sz))]
    # Godot Transform3D(xx, xy, xz, yx, yy, yz, zx, zy, zz, ox, oy, oz) given as basis columns x,y,z
    vals = cols[0] + cols[1] + cols[2] + [px, py, -pz]
    return 'Transform3D(%s)' % ', '.join(g(v) for v in vals)


def safe_name(n):
    n = re.sub(r'[.:@/"%]', '_', n)
    return n or 'Node'


# ----------------------------------------------------------------- materials
def read_material(path):
    objs = parse_unity_yaml(path)
    for _, (cls, typ, d, _) in objs.items():
        if typ == 'Material':
            col = [1, 1, 1, 1]
            for c in d.get('m_SavedProperties', {}).get('m_Colors', []):
                if '_Color' in c:
                    cc = c['_Color']
                    col = [float(cc['r']), float(cc['g']), float(cc['b']), float(cc['a'])]
            tex = None
            for t in d.get('m_SavedProperties', {}).get('m_TexEnvs', []):
                if '_MainTex' in t:
                    r = ref_of(t['_MainTex']['m_Texture'])
                    if r and r[1]:
                        tex = GUID2PATH.get(r[1])
            return d.get('m_Name', os.path.basename(path)[:-4]), col, tex
    return None


MATERIALS = {}  # unity relative path -> res path


def material_res(unity_rel):
    if unity_rel in MATERIALS:
        return MATERIALS[unity_rel]
    name = os.path.splitext(os.path.basename(unity_rel))[0]
    out = 'res://materials/%s.tres' % safe_name(name)
    full = os.path.join(ASSETS, unity_rel)
    col = [0.8, 0.8, 0.8, 1]
    transparent = False
    if os.path.exists(full) and unity_rel.endswith('.mat'):
        m = read_material(full)
        if m:
            col = m[1]
    if 'ForceShield' in unity_rel:
        col = [0.25, 0.6, 1.0, 0.25]
        transparent = True
    os.makedirs(os.path.join(GODOT, 'materials'), exist_ok=True)
    with open(os.path.join(GODOT, 'materials', safe_name(name) + '.tres'), 'w') as f:
        f.write('[gd_resource type="StandardMaterial3D" format=3]\n\n[resource]\n')
        f.write('resource_name = "%s"\n' % name)
        if transparent:
            f.write('transparency = 1\ncull_mode = 2\nshading_mode = 0\n')
        f.write('albedo_color = Color(%s, %s, %s, %s)\n' % (g(col[0]), g(col[1]), g(col[2]),
                                                             g(col[3] if transparent else 1)))
    MATERIALS[unity_rel] = out
    return out


# ------------------------------------------------------------- scene writing
class Scene:
    def __init__(self):
        self.ext = []  # (type, path)
        self.subs = []  # text blocks
        self.nodes = []  # text blocks
        self.n_sub = 0

    def ext_id(self, typ, path):
        for i, (t, p) in enumerate(self.ext):
            if p == path:
                return '%d' % (i + 1)
        self.ext.append((typ, path))
        return '%d' % len(self.ext)

    def sub(self, typ, props):
        self.n_sub += 1
        sid = '%s_%d' % (typ, self.n_sub)
        block = '[sub_resource type="%s" id="%s"]\n' % (typ, sid)
        for k, v in props.items():
            block += '%s = %s\n' % (k, v)
        self.subs.append(block)
        return sid

    def text(self):
        out = '[gd_scene format=3]\n\n'
        for i, (t, p) in enumerate(self.ext):
            out += '[ext_resource type="%s" path="%s" id="%d"]\n' % (t, p, i + 1)
        if self.ext:
            out += '\n'
        for s in self.subs:
            out += s + '\n'
        out += '\n'.join(self.nodes)
        return out


def mesh_sub(scene, kind):
    if kind == 'Cube':
        return scene.sub('BoxMesh', {'size': 'Vector3(1, 1, 1)'})
    if kind == 'Cylinder':
        return scene.sub('CylinderMesh', {'top_radius': '0.5', 'bottom_radius': '0.5', 'height': '2.0',
                                          'radial_segments': '20', 'rings': '1'})
    if kind == 'Sphere':
        return scene.sub('SphereMesh', {'radius': '0.5', 'height': '1.0', 'radial_segments': '20',
                                        'rings': '10'})
    if kind == 'Capsule':
        return scene.sub('CapsuleMesh', {'radius': '0.5', 'height': '2.0'})
    if kind == 'Quad':
        return scene.sub('QuadMesh', {'size': 'Vector2(1, 1)'})
    if kind == 'Plane':
        return scene.sub('PlaneMesh', {'size': 'Vector2(10, 10)'})
    return None


def unity_ref_to_res(fid, guid):
    """Reference to another asset -> (godot type, res path) or None."""
    path = GUID2PATH.get(guid)
    if not path:
        return None
    if path.endswith('.prefab'):
        return 'PackedScene', 'res://prefabs/%s.tscn' % prefab_out_name(path)
    if path.lower().endswith('.fbx'):
        sub = 'nature' if '/Nature/' in path else 'fbx'
        return 'PackedScene', 'res://assets/%s/%s' % (sub, os.path.basename(path))
    return None


def prefab_out_name(unity_rel):
    base = os.path.splitext(os.path.basename(unity_rel))[0]
    return safe_name(base.replace(' ', '_'))


class PrefabConverter:
    """Converts one prefab file."""

    def __init__(self, unity_rel):
        self.rel = unity_rel
        self.objs = parse_unity_yaml(os.path.join(ASSETS, unity_rel))
        self.scene = Scene()
        self.go_path = {}  # gameobject fileID -> node path ('.' for root)
        self.comp_go = {}  # component fileID -> gameobject fileID
        self.instance_path = {}  # prefab instance fileID -> node path
        self.tr_of_go = {}
        self.children = {}
        self._sibling_names = {}
        self._node_name = {}
        for fid, (cls, typ, d, stripped) in self.objs.items():
            if typ in ('Transform', 'RectTransform') and not stripped:
                go = d['m_GameObject']['fileID']
                self.tr_of_go[go] = fid
                par = d.get('m_Father', {}).get('fileID', '0')
                self.children.setdefault(par, []).append(fid)
            if 'm_GameObject' in d and not stripped:
                self.comp_go[fid] = d['m_GameObject']['fileID']

    # find unity GO name
    def go_name(self, go):
        return self.objs[go][2].get('m_Name', 'Node')

    def resolve_node_ref(self, fid, from_path):
        """Reference to an object inside this prefab -> NodePath string relative to from_path."""
        if fid == '0' or fid not in self.objs:
            return None
        cls, typ, d, stripped = self.objs[fid]
        target = None
        if stripped:
            inst = d.get('m_PrefabInstance', {}).get('fileID')
            src = ref_of(d.get('m_CorrespondingSourceObject'))
            if inst in self.instance_path and src:
                ipath = self.instance_path[inst]
                src_path = GUID2PATH.get(src[1])
                if src_path and src_path.endswith('.prefab'):
                    sub = PrefabConverter.get(src_path)
                    p = sub.path_of_object(src[0])
                    if p is not None:
                        target = ipath if p == '.' else ipath + '/' + p
        else:
            target = self.path_of_object(fid)
        if target is None:
            return None
        return rel_path(from_path, target)

    def path_of_object(self, fid):
        if fid not in self.objs:
            return None
        cls, typ, d, stripped = self.objs[fid]
        if typ == 'GameObject':
            return self.go_path.get(fid)
        if typ == 'MonoBehaviour':
            go = self.comp_go.get(fid)
            name = self.script_name(d)
            base = self.go_path.get(go)
            if base is None:
                return None
            return name if base == '.' else base + '/' + name
        go = self.comp_go.get(fid)
        if go is not None:
            base = self.go_path.get(go)
            if typ == 'LineRenderer' and base is not None:
                return 'LineRenderer' if base == '.' else base + '/LineRenderer'
            return base
        return None

    def script_name(self, d):
        r = ref_of(d.get('m_Script'))
        if r and r[1] in GUID2PATH:
            return os.path.splitext(os.path.basename(GUID2PATH[r[1]]))[0]
        return None

    CACHE = {}

    @staticmethod
    def get(unity_rel):
        if unity_rel not in PrefabConverter.CACHE:
            c = PrefabConverter(unity_rel)
            c.convert()
            PrefabConverter.CACHE[unity_rel] = c
        return PrefabConverter.CACHE[unity_rel]

    def convert(self):
        roots = [t for t in self.children.get('0', [])]
        assert len(roots) == 1, (self.rel, roots)
        # first pass: assign paths
        self.assign_paths(roots[0], None)
        self.emit(roots[0], None, is_root=True)
        out = os.path.join(GODOT, 'prefabs', prefab_out_name(self.rel) + '.tscn')
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, 'w') as f:
            f.write(self.scene.text())

    def assign_paths(self, tr, parent_path, used=None):
        d = self.objs[tr][2]
        go = d['m_GameObject']['fileID']
        name = safe_name(self.go_name(go))
        if parent_path is None:
            path = '.'
        else:
            sib = self._sibling_names.setdefault(parent_path, set())
            base, k = name, 1
            while name in sib:
                k += 1
                name = '%s_%d' % (base, k)
            sib.add(name)
            path = name if parent_path == '.' else parent_path + '/' + name
        self.go_path[go] = path
        self._node_name[tr] = name
        for ch in self.children.get(tr, []):
            self.assign_paths(ch, path)
        # prefab instances parented here
        for fid, (cls, typ, dd, stripped) in self.objs.items():
            if typ == 'PrefabInstance':
                par = dd['m_Modification'].get('m_TransformParent', {}).get('fileID')
                if par == tr and fid not in self.instance_path:
                    iname = self.instance_name(dd)
                    sib = self._sibling_names.setdefault(path, set())
                    base, k = iname, 1
                    while iname in sib:
                        k += 1
                        iname = '%s_%d' % (base, k)
                    sib.add(iname)
                    self.instance_path[fid] = iname if path == '.' else path + '/' + iname

    def instance_name(self, dd):
        for m in dd['m_Modification'].get('m_Modifications', []):
            if m.get('propertyPath') == 'm_Name':
                return safe_name(m.get('value', 'Instance'))
        src = ref_of(dd.get('m_SourcePrefab'))
        return safe_name(os.path.splitext(os.path.basename(GUID2PATH.get(src[1], 'Instance')))[0])

    def emit(self, tr, parent_path, is_root=False):
        d = self.objs[tr][2]
        go = d['m_GameObject']['fileID']
        path = self.go_path[go]
        name = self._node_name[tr]
        god = self.objs[go][2]
        comps = [c['component']['fileID'] for c in god.get('m_Component', [])]
        mesh_kind, mats, mesh_enabled = None, [], True
        for c in comps:
            if c not in self.objs:
                continue
            cls, typ, cd, _ = self.objs[c]
            if typ == 'MeshFilter':
                r = ref_of(cd.get('m_Mesh'))
                if r and r[1] in ('0000000000000000e000000000000000',):
                    mesh_kind = BUILTIN_MESH.get(r[0])
            if typ == 'MeshRenderer':
                mesh_enabled = cd.get('m_Enabled', '1') == '1'
                for m in cd.get('m_Materials', []):
                    r = ref_of(m)
                    if r and r[1] in GUID2PATH:
                        mats.append(GUID2PATH[r[1]])
                    else:
                        mats.append('Default')
        pos = fvec(d['m_LocalPosition'])
        rot = fvec(d['m_LocalRotation'], ('x', 'y', 'z', 'w'))
        scl = fvec(d['m_LocalScale'])
        has_sprite = any(self.objs.get(c, (0, ''))[1] in ('SpriteMask',) for c in comps)
        typ = 'MeshInstance3D' if (mesh_kind or has_sprite) else 'Node3D'
        header = '[node name="%s" type="%s"' % (name, typ)
        if not is_root:
            header += ' parent="%s"' % (parent_path)
        header += ']\n'
        body = ''
        if not is_root:
            body += 'transform = %s\n' % transform_str(pos, rot, scl)
        else:
            # keep root scale (some prefabs have non unit root scale), drop position/rotation
            if any(abs(s - 1) > 1e-6 for s in scl):
                body += 'transform = %s\n' % transform_str((0, 0, 0), (0, 0, 0, 1), scl)
        if mesh_kind:
            mid = mesh_sub(self.scene, mesh_kind)
            body += 'mesh = SubResource("%s")\n' % mid
            if mats:
                body += 'surface_material_override/0 = ExtResource("%s")\n' % self.scene.ext_id(
                    'Material', material_res(mats[0]))
            if not mesh_enabled:
                body += 'visible = false\n'
        elif has_sprite:
            # cooldown indicator (Unity SpriteMask + radial sprite)
            mid = self.scene.sub('QuadMesh', {'size': 'Vector2(1, 1)'})
            body += 'mesh = SubResource("%s")\n' % mid
            body += 'surface_material_override/0 = ExtResource("%s")\n' % self.scene.ext_id(
                'Material', 'res://materials/Cooldown.tres')
            body += 'visible = false\n'
            body += 'script = ExtResource("%s")\n' % self.scene.ext_id('Script', 'res://scripts/components/Cooldown.gd')
        self.scene.nodes.append(header + body)
        # components
        for c in comps:
            if c not in self.objs:
                continue
            cls, ctyp, cd, _ = self.objs[c]
            if ctyp == 'MonoBehaviour':
                sname = self.script_name(cd)
                if not sname or not os.path.exists(os.path.join(ASSETS, 'Scripts', sname + '.cs')):
                    continue
                self.emit_component(path, sname, cd)
            elif ctyp == 'LineRenderer':
                self.emit_line_renderer(path, cd)
        for ch in self.children.get(tr, []):
            self.emit(ch, path)
        # prefab instances under this transform
        for fid, (cls, ityp, dd, stripped) in self.objs.items():
            if ityp == 'PrefabInstance' and dd['m_Modification'].get('m_TransformParent', {}).get('fileID') == tr:
                self.emit_instance(fid, dd, path)

    def emit_line_renderer(self, path, cd):
        params = cd.get('m_Parameters', {})
        width = float(params.get('widthMultiplier', '0.05'))
        try:
            width *= float(params['widthCurve']['m_Curve'][0]['value'])
        except (KeyError, IndexError, TypeError):
            pass
        node = '[node name="LineRenderer" type="MeshInstance3D" parent="%s"]\n' % path
        node += 'script = ExtResource("%s")\n' % self.scene.ext_id('Script', 'res://scripts/components/LineRenderer.gd')
        node += 'width = %s\n' % g(width)
        node += 'loop = %s\n' % ('true' if cd.get('m_Loop', '0') == '1' else 'false')
        node += 'world_space = %s\n' % ('true' if cd.get('m_UseWorldSpace', '1') == '1' else 'false')
        self.scene.nodes.append(node)

    def emit_instance(self, fid, dd, parent_path):
        src = ref_of(dd.get('m_SourcePrefab'))
        src_rel = GUID2PATH.get(src[1])
        ipath = self.instance_path[fid]
        name = ipath.split('/')[-1]
        if src_rel.lower().endswith('.fbx'):
            res = unity_ref_to_res('100100000', src[1])[1]
        else:
            PrefabConverter.get(src_rel)
            res = 'res://prefabs/%s.tscn' % prefab_out_name(src_rel)
        eid = self.scene.ext_id('PackedScene', res)
        # root transform modifications
        src_conv = PrefabConverter.get(src_rel) if src_rel.endswith('.prefab') else None
        pos, rot, scl = None, None, None
        props = {}
        if src_conv:
            root_tr = src_conv.children['0'][0]
            sd = src_conv.objs[root_tr][2]
            pos = fvec(sd['m_LocalPosition'])
            rot = fvec(sd['m_LocalRotation'], ('x', 'y', 'z', 'w'))
            scl = fvec(sd['m_LocalScale'])
        else:
            pos, rot, scl = [0, 0, 0], [0, 0, 0, 1], [1, 1, 1]
        for m in dd['m_Modification'].get('m_Modifications', []):
            pp, val = m.get('propertyPath', ''), m.get('value', '')
            tgt = ref_of(m.get('target'))
            is_root_tr = src_conv is None or (tgt and tgt[0] == src_conv.children['0'][0])
            mm = re.match(r'm_Local(Position|Rotation|Scale)\.([xyzw])', pp)
            if mm and is_root_tr:
                arr = {'Position': pos, 'Rotation': rot, 'Scale': scl}[mm.group(1)]
                arr['xyzw'.index(mm.group(2))] = float(val)
        node = '[node name="%s" parent="%s" instance=ExtResource("%s")]\n' % (name, parent_path, eid)
        node += 'transform = %s\n' % transform_str(pos, rot, scl)
        self.scene.nodes.append(node)

    def emit_component(self, path, sname, cd):
        node = '[node name="%s" type="Node" parent="%s"]\n' % (sname, path)
        node += 'script = ExtResource("%s")\n' % self.scene.ext_id('Script', 'res://scripts/components/%s.gd' % sname)
        comp_path = sname if path == '.' else path + '/' + sname
        for k, v in cd.items():
            if k in SKIP_FIELDS or k.startswith('m_'):
                continue
            val = self.convert_value(k, v, comp_path)
            if val is not None:
                node += '%s = %s\n' % (k, val)
        self.scene.nodes.append(node)

    def convert_value(self, key, v, comp_path):
        if key in HEX_INT_FIELDS and isinstance(v, str):
            ints = [int.from_bytes(bytes.fromhex(v[i:i + 8]), 'little', signed=True) for i in range(0, len(v), 8)]
            return 'PackedInt32Array(%s)' % ', '.join(str(i) for i in ints)
        if key in HEX_BOOL_FIELDS and isinstance(v, str):
            bools = ['true' if v[i:i + 2] != '00' else 'false' for i in range(0, len(v), 2)]
            return '[%s]' % ', '.join(bools)
        if key in BOOL_FIELDS and isinstance(v, str):
            return 'true' if v not in ('0', '') else 'false'
        if key.endswith('HexCode') and isinstance(v, str):
            return '"%s"' % v
        if isinstance(v, str):
            try:
                f = float(v)
            except ValueError:
                return '"%s"' % v
            return g(f)
        if isinstance(v, dict):
            if 'r' in v and 'g' in v:
                return 'Color(%s, %s, %s, 1)' % (g(float(v['r'])), g(float(v['g'])), g(float(v['b'])))
            if 'fileID' in v:
                return self.convert_ref(v, comp_path)
            if 'x' in v:
                return None
            return None
        if isinstance(v, list):
            if not v:
                return None
            items = [self.convert_value(key, i, comp_path) for i in v]
            if all(isinstance(i, dict) and 'r' in i for i in v):
                return '[%s]' % ', '.join(items)
            if all(isinstance(i, str) for i in v):
                return '[%s]' % ', '.join(items)
            items = [i if i is not None else 'null' for i in items]
            return '[%s]' % ', '.join(items)
        return None

    def convert_ref(self, v, comp_path):
        fid, guid = v['fileID'], v.get('guid')
        if fid == '0':
            return None
        if guid:
            r = unity_ref_to_res(fid, guid)
            if r:
                return 'ExtResource("%s")' % self.scene.ext_id(*r)
            return None
        p = self.resolve_node_ref(fid, comp_path)
        if p is None:
            return None
        return 'NodePath("%s")' % p


def rel_path(from_path, target):
    """NodePath from node at from_path (relative to root '.') to target."""
    fp = [] if from_path == '.' else from_path.split('/')
    tp = [] if target == '.' else target.split('/')
    i = 0
    while i < len(fp) and i < len(tp) and fp[i] == tp[i]:
        i += 1
    ups = ['..'] * (len(fp) - i)
    rest = tp[i:]
    parts = ups + rest
    return '/'.join(parts) if parts else '.'


def convert_wall_model(unity_rel):
    """WallModells prefabs: root -> 'lower'/'upper' -> FBX instance."""
    objs = parse_unity_yaml(os.path.join(ASSETS, unity_rel))
    fbx = None
    for fid, (cls, typ, d, stripped) in objs.items():
        if typ == 'MeshFilter' and fbx is None:
            r = ref_of(d.get('m_Mesh'))
            if r and r[1] in GUID2PATH:
                fbx = os.path.splitext(os.path.basename(GUID2PATH[r[1]]))[0] + '.fbx'
        if typ == 'PrefabInstance':
            src = ref_of(d.get('m_SourcePrefab'))
            fbx = os.path.splitext(os.path.basename(GUID2PATH[src[1]]))[0] + '.fbx'
    s = Scene()
    eid = s.ext_id('PackedScene', 'res://assets/fbx/%s' % fbx)
    sid = s.ext_id('Script', 'res://scripts/WallModel.gd')
    s.nodes.append('[node name="%s" type="Node3D"]\nscript = ExtResource("%s")\n' % (prefab_out_name(unity_rel), sid))
    # Imported models are 3 units wide and mirrored compared to Unity:
    # scale to one tile and turn by 180 degrees around y.
    k = 1.0 / 3.0
    s.nodes.append('[node name="Model" parent="." instance=ExtResource("%s")]\n'
                   'transform = Transform3D(%s, 0, 0, 0, %s, 0, 0, 0, %s, 0, 0, 0)\n' % (eid, g(-k), g(k), g(-k)))
    out = os.path.join(GODOT, 'prefabs', 'walls', prefab_out_name(unity_rel) + '.tscn')
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, 'w') as f:
        f.write(s.text())


def unity_ref_to_res_wall(path):
    return 'res://prefabs/walls/%s.tscn' % prefab_out_name(path)


_orig_unity_ref_to_res = unity_ref_to_res


def unity_ref_to_res(fid, guid):  # noqa: F811  (wall models live in a sub folder)
    path = GUID2PATH.get(guid)
    if path and 'WallModells' in path and path.endswith('.prefab'):
        return 'PackedScene', unity_ref_to_res_wall(path)
    return _orig_unity_ref_to_res(fid, guid)


def main():
    os.makedirs(os.path.join(GODOT, 'materials'), exist_ok=True)
    with open(os.path.join(GODOT, 'materials', 'Cooldown.tres'), 'w') as f:
        f.write('[gd_resource type="ShaderMaterial" load_steps=2 format=3]\n\n'
                '[ext_resource type="Shader" path="res://shaders/cooldown.gdshader" id="1"]\n\n'
                '[resource]\nshader = ExtResource("1")\n')
    for p in sorted(glob.glob(os.path.join(ASSETS, 'Prefabs', 'WallModells', '*.prefab'))):
        convert_wall_model(p[len(ASSETS) + 1:])
    wanted = sys.argv[1:] or [
        'ArcRenderer', 'Base', 'BlockCorner', 'BlockCross', 'BlockLine', 'BlockThree', 'Bullet', 'Cannon',
        'Cannon22a', 'Cannon22b', 'Cannon22c', 'Cannon22d', 'Cannon33a', 'Cannon33b', 'Cannon33c',
        'ClusterBomb', 'Flak22', 'Rocket', 'RocketModel', 'RocketStation', 'ShieldGen22', 'Ship', 'Slab',
        'StraightShooter', 'Supply', 'Supply22', 'Upgrade_a', 'Upgrade_b', 'Maker_BigLeafTree',
        'Maker_Boulder', 'Maker_Bush', 'Maker_Evergreen', 'Maker_Grass', 'Maker_LeafTree', 'Maker_Mushroom',
        'Maker_Stones', 'Maker_Twiggy', 'Progress Bar']
    for name in wanted:
        rel = 'Prefabs/%s.prefab' % name
        PrefabConverter.get(rel)
        print('converted', rel)


if __name__ == '__main__':
    main()
