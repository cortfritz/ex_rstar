use std::sync::Mutex;

use rstar::{RTree, AABB};
use rustler::{Atom, Env, NifResult, ResourceArc, Term};

mod atoms {
    rustler::atoms! {
        ok,
        error,
        not_found,
    }
}

// --- 2D ---

#[derive(Debug, Clone, PartialEq)]
struct Point2D {
    x: f64,
    y: f64,
    data: Option<Vec<u8>>,
}

impl rstar::RTreeObject for Point2D {
    type Envelope = AABB<[f64; 2]>;

    fn envelope(&self) -> Self::Envelope {
        AABB::from_point([self.x, self.y])
    }
}

impl rstar::PointDistance for Point2D {
    fn distance_2(&self, point: &[f64; 2]) -> f64 {
        let dx = self.x - point[0];
        let dy = self.y - point[1];
        dx * dx + dy * dy
    }
}

struct RTreeResource(Mutex<RTree<Point2D>>);

// --- 3D ---

#[derive(Debug, Clone, PartialEq)]
struct Point3D {
    x: f64,
    y: f64,
    z: f64,
    data: Option<Vec<u8>>,
}

impl rstar::RTreeObject for Point3D {
    type Envelope = AABB<[f64; 3]>;

    fn envelope(&self) -> Self::Envelope {
        AABB::from_point([self.x, self.y, self.z])
    }
}

impl rstar::PointDistance for Point3D {
    fn distance_2(&self, point: &[f64; 3]) -> f64 {
        let dx = self.x - point[0];
        let dy = self.y - point[1];
        let dz = self.z - point[2];
        dx * dx + dy * dy + dz * dz
    }
}

struct RTree3DResource(Mutex<RTree<Point3D>>);

#[allow(non_local_definitions, unused_must_use)]
fn load(env: Env, _info: Term) -> bool {
    rustler::resource!(RTreeResource, env);
    rustler::resource!(RTree3DResource, env);
    true
}

// --- Construction ---

#[rustler::nif]
fn new_tree() -> ResourceArc<RTreeResource> {
    ResourceArc::new(RTreeResource(Mutex::new(RTree::new())))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn bulk_load(points: Vec<(f64, f64, Vec<u8>)>) -> ResourceArc<RTreeResource> {
    let items: Vec<Point2D> = points
        .into_iter()
        .map(|(x, y, data)| {
            let d = if data.is_empty() { None } else { Some(data) };
            Point2D { x, y, data: d }
        })
        .collect();
    ResourceArc::new(RTreeResource(Mutex::new(RTree::bulk_load(items))))
}

// --- Insertion / Removal ---

#[rustler::nif]
fn insert(tree: ResourceArc<RTreeResource>, x: f64, y: f64, data: Vec<u8>) -> Atom {
    let d = if data.is_empty() { None } else { Some(data) };
    tree.0.lock().unwrap().insert(Point2D { x, y, data: d });
    atoms::ok()
}

#[rustler::nif]
fn remove(tree: ResourceArc<RTreeResource>, x: f64, y: f64) -> (Atom, bool) {
    let mut t = tree.0.lock().unwrap();
    let target = {
        let point = [x, y];
        t.locate_at_point(&point).cloned()
    };
    match target {
        Some(p) => {
            t.remove(&p);
            (atoms::ok(), true)
        }
        None => (atoms::ok(), false),
    }
}

// --- Queries ---

#[rustler::nif]
fn size(tree: ResourceArc<RTreeResource>) -> usize {
    tree.0.lock().unwrap().size()
}

#[rustler::nif]
fn nearest_neighbor(tree: ResourceArc<RTreeResource>, x: f64, y: f64) -> NifResult<(Atom, (f64, f64, Vec<u8>))> {
    let t = tree.0.lock().unwrap();
    match t.nearest_neighbor(&[x, y]) {
        Some(p) => Ok((atoms::ok(), (p.x, p.y, p.data.clone().unwrap_or_default()))),
        None => Err(rustler::Error::Term(Box::new(atoms::not_found()))),
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nearest_neighbors(
    tree: ResourceArc<RTreeResource>,
    x: f64,
    y: f64,
    count: usize,
) -> Vec<(f64, f64, Vec<u8>, f64)> {
    let t = tree.0.lock().unwrap();
    t.nearest_neighbor_iter_with_distance_2(&[x, y])
        .take(count)
        .map(|(p, dist2)| (p.x, p.y, p.data.clone().unwrap_or_default(), dist2))
        .collect()
}

#[rustler::nif(schedule = "DirtyCpu")]
fn locate_in_envelope(
    tree: ResourceArc<RTreeResource>,
    min_x: f64,
    min_y: f64,
    max_x: f64,
    max_y: f64,
) -> Vec<(f64, f64, Vec<u8>)> {
    let t = tree.0.lock().unwrap();
    let envelope = AABB::from_corners([min_x, min_y], [max_x, max_y]);
    t.locate_in_envelope(&envelope)
        .map(|p| (p.x, p.y, p.data.clone().unwrap_or_default()))
        .collect()
}

#[rustler::nif(schedule = "DirtyCpu")]
fn locate_in_envelope_intersecting(
    tree: ResourceArc<RTreeResource>,
    min_x: f64,
    min_y: f64,
    max_x: f64,
    max_y: f64,
) -> Vec<(f64, f64, Vec<u8>)> {
    let t = tree.0.lock().unwrap();
    let envelope = AABB::from_corners([min_x, min_y], [max_x, max_y]);
    t.locate_in_envelope_intersecting(&envelope)
        .map(|p| (p.x, p.y, p.data.clone().unwrap_or_default()))
        .collect()
}

#[rustler::nif(schedule = "DirtyCpu")]
fn locate_within_distance(
    tree: ResourceArc<RTreeResource>,
    x: f64,
    y: f64,
    max_distance_squared: f64,
) -> Vec<(f64, f64, Vec<u8>)> {
    let t = tree.0.lock().unwrap();
    t.locate_within_distance([x, y], max_distance_squared)
        .map(|p| (p.x, p.y, p.data.clone().unwrap_or_default()))
        .collect()
}

#[rustler::nif]
fn locate_at_point(
    tree: ResourceArc<RTreeResource>,
    x: f64,
    y: f64,
) -> NifResult<(Atom, (f64, f64, Vec<u8>))> {
    let t = tree.0.lock().unwrap();
    match t.locate_at_point(&[x, y]) {
        Some(p) => Ok((atoms::ok(), (p.x, p.y, p.data.clone().unwrap_or_default()))),
        None => Err(rustler::Error::Term(Box::new(atoms::not_found()))),
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn drain_within_distance(
    tree: ResourceArc<RTreeResource>,
    x: f64,
    y: f64,
    max_distance_squared: f64,
) -> Vec<(f64, f64, Vec<u8>)> {
    let mut t = tree.0.lock().unwrap();
    t.drain_within_distance([x, y], max_distance_squared)
        .map(|p| (p.x, p.y, p.data.clone().unwrap_or_default()))
        .collect()
}

// --- 3D Construction ---

#[rustler::nif]
fn new_tree_3d() -> ResourceArc<RTree3DResource> {
    ResourceArc::new(RTree3DResource(Mutex::new(RTree::new())))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn bulk_load_3d(points: Vec<(f64, f64, f64, Vec<u8>)>) -> ResourceArc<RTree3DResource> {
    let items: Vec<Point3D> = points
        .into_iter()
        .map(|(x, y, z, data)| {
            let d = if data.is_empty() { None } else { Some(data) };
            Point3D { x, y, z, data: d }
        })
        .collect();
    ResourceArc::new(RTree3DResource(Mutex::new(RTree::bulk_load(items))))
}

// --- 3D Insertion / Removal ---

#[rustler::nif]
fn insert_3d(tree: ResourceArc<RTree3DResource>, x: f64, y: f64, z: f64, data: Vec<u8>) -> Atom {
    let d = if data.is_empty() { None } else { Some(data) };
    tree.0.lock().unwrap().insert(Point3D { x, y, z, data: d });
    atoms::ok()
}

#[rustler::nif]
fn remove_3d(tree: ResourceArc<RTree3DResource>, x: f64, y: f64, z: f64) -> (Atom, bool) {
    let mut t = tree.0.lock().unwrap();
    let target = {
        let point = [x, y, z];
        t.locate_at_point(&point).cloned()
    };
    match target {
        Some(p) => {
            t.remove(&p);
            (atoms::ok(), true)
        }
        None => (atoms::ok(), false),
    }
}

// --- 3D Queries ---

#[rustler::nif]
fn size_3d(tree: ResourceArc<RTree3DResource>) -> usize {
    tree.0.lock().unwrap().size()
}

#[rustler::nif]
fn nearest_neighbor_3d(tree: ResourceArc<RTree3DResource>, x: f64, y: f64, z: f64) -> NifResult<(Atom, (f64, f64, f64, Vec<u8>))> {
    let t = tree.0.lock().unwrap();
    match t.nearest_neighbor(&[x, y, z]) {
        Some(p) => Ok((atoms::ok(), (p.x, p.y, p.z, p.data.clone().unwrap_or_default()))),
        None => Err(rustler::Error::Term(Box::new(atoms::not_found()))),
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nearest_neighbors_3d(
    tree: ResourceArc<RTree3DResource>,
    x: f64,
    y: f64,
    z: f64,
    count: usize,
) -> Vec<(f64, f64, f64, Vec<u8>, f64)> {
    let t = tree.0.lock().unwrap();
    t.nearest_neighbor_iter_with_distance_2(&[x, y, z])
        .take(count)
        .map(|(p, dist2)| (p.x, p.y, p.z, p.data.clone().unwrap_or_default(), dist2))
        .collect()
}

#[rustler::nif(schedule = "DirtyCpu")]
fn locate_in_envelope_3d(
    tree: ResourceArc<RTree3DResource>,
    min_x: f64,
    min_y: f64,
    min_z: f64,
    max_x: f64,
    max_y: f64,
    max_z: f64,
) -> Vec<(f64, f64, f64, Vec<u8>)> {
    let t = tree.0.lock().unwrap();
    let envelope = AABB::from_corners([min_x, min_y, min_z], [max_x, max_y, max_z]);
    t.locate_in_envelope(&envelope)
        .map(|p| (p.x, p.y, p.z, p.data.clone().unwrap_or_default()))
        .collect()
}

#[rustler::nif(schedule = "DirtyCpu")]
fn locate_in_envelope_intersecting_3d(
    tree: ResourceArc<RTree3DResource>,
    min_x: f64,
    min_y: f64,
    min_z: f64,
    max_x: f64,
    max_y: f64,
    max_z: f64,
) -> Vec<(f64, f64, f64, Vec<u8>)> {
    let t = tree.0.lock().unwrap();
    let envelope = AABB::from_corners([min_x, min_y, min_z], [max_x, max_y, max_z]);
    t.locate_in_envelope_intersecting(&envelope)
        .map(|p| (p.x, p.y, p.z, p.data.clone().unwrap_or_default()))
        .collect()
}

#[rustler::nif(schedule = "DirtyCpu")]
fn locate_within_distance_3d(
    tree: ResourceArc<RTree3DResource>,
    x: f64,
    y: f64,
    z: f64,
    max_distance_squared: f64,
) -> Vec<(f64, f64, f64, Vec<u8>)> {
    let t = tree.0.lock().unwrap();
    t.locate_within_distance([x, y, z], max_distance_squared)
        .map(|p| (p.x, p.y, p.z, p.data.clone().unwrap_or_default()))
        .collect()
}

#[rustler::nif]
fn locate_at_point_3d(
    tree: ResourceArc<RTree3DResource>,
    x: f64,
    y: f64,
    z: f64,
) -> NifResult<(Atom, (f64, f64, f64, Vec<u8>))> {
    let t = tree.0.lock().unwrap();
    match t.locate_at_point(&[x, y, z]) {
        Some(p) => Ok((atoms::ok(), (p.x, p.y, p.z, p.data.clone().unwrap_or_default()))),
        None => Err(rustler::Error::Term(Box::new(atoms::not_found()))),
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn drain_within_distance_3d(
    tree: ResourceArc<RTree3DResource>,
    x: f64,
    y: f64,
    z: f64,
    max_distance_squared: f64,
) -> Vec<(f64, f64, f64, Vec<u8>)> {
    let mut t = tree.0.lock().unwrap();
    t.drain_within_distance([x, y, z], max_distance_squared)
        .map(|p| (p.x, p.y, p.z, p.data.clone().unwrap_or_default()))
        .collect()
}

rustler::init!("Elixir.ExRstar.Native", load = load);
