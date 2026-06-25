import { useState, useEffect, useMemo, useCallback, useRef } from 'react';
import { MapContainer, TileLayer, Polyline, Marker, useMapEvents, useMap } from 'react-leaflet';
import { MapPin, Plus, X, Image as ImageIcon, Check, Trash2, Upload, ClipboardList, RefreshCw, LogOut } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import L from 'leaflet';

// Fix Leaflet default marker icon issue in Vite
delete (L.Icon.Default.prototype as { _getIconUrl?: unknown })._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
});

const API_BASE = import.meta.env.VITE_API_BASE || 'https://stairs-paths-api.luke-mulcahy.workers.dev';
// Admin API is served by Pages Functions on this same (Access-protected) origin.
const ADMIN_BASE = '/api/admin';

interface StairPath {
  id: number;
  name: string;
  startLatitude: number;
  startLongitude: number;
  endLatitude: number;
  endLongitude: number;
  pathData?: string;
}

interface Submission {
  id: number;
  kind: 'create' | 'edit';
  target_id: number | null;
  payload: string;
  submitter: string | null;
  created_at: string;
}

interface PendingPhoto {
  id: string;
  stairpath_id: number;
  stairpath_name: string | null;
}

function parsePoints(pathData: string | undefined, fallback: [number, number][]): [number, number][] {
  if (!pathData) return fallback;
  try {
    let v: unknown = typeof pathData === 'string' ? JSON.parse(pathData) : pathData;
    // Tolerate legacy double-encoded data (a JSON string containing JSON) from the old
    // iOS encoder, which would otherwise parse to a string and crash <Polyline>.
    if (typeof v === 'string') v = JSON.parse(v);
    if (
      Array.isArray(v) &&
      v.length > 0 &&
      v.every((pt) => Array.isArray(pt) && pt.length >= 2 && typeof pt[0] === 'number' && typeof pt[1] === 'number')
    ) {
      return v as [number, number][];
    }
    return fallback;
  } catch {
    return fallback;
  }
}

export default function App() {
  const [paths, setPaths] = useState<StairPath[]>([]);
  const [selectedPath, setSelectedPath] = useState<StairPath | null>(null);
  const [photos, setPhotos] = useState<string[]>([]);
  const [isLoadingPhotos, setIsLoadingPhotos] = useState(false);
  
  // Creation state
  const [isCreating, setIsCreating] = useState(false);
  const [createStep, setCreateStep] = useState<0|1>(0);
  const [createPoints, setCreatePoints] = useState<[number, number][]>([]);
  const [newName, setNewName] = useState('');

  // Edit state
  const [isEditing, setIsEditing] = useState(false);
  const [editPoints, setEditPoints] = useState<[number, number][]>([]);
  const [editName, setEditName] = useState('');

  // Admin / review state
  const [view, setView] = useState<'map' | 'queue'>('map');
  const [submissions, setSubmissions] = useState<Submission[]>([]);
  const [pendingPhotos, setPendingPhotos] = useState<PendingPhoto[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [isUploading, setIsUploading] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const loadPaths = useCallback(async () => {
    try {
      const res = await fetch(`${API_BASE}/stairpaths`);
      if (!res.ok) throw new Error();
      setPaths(await res.json());
    } catch {
      setError('Could not load paths.');
    }
  }, []);

  const loadQueue = useCallback(async () => {
    try {
      const res = await fetch(`${ADMIN_BASE}/queue`);
      if (!res.ok) throw new Error();
      const data = await res.json();
      setSubmissions(data.submissions ?? []);
      setPendingPhotos(data.photos ?? []);
    } catch {
      setError('Could not load the review queue.');
    }
  }, []);

  const queueCount = submissions.length + pendingPhotos.length;

  const hasChanges = useMemo(() => {
    if (!selectedPath || !isEditing) return false;
    let originalPoints: [number, number][] = [
      [selectedPath.startLatitude, selectedPath.startLongitude],
      [selectedPath.endLatitude, selectedPath.endLongitude]
    ];
    originalPoints = parsePoints(selectedPath.pathData, originalPoints);
    if (selectedPath.name !== editName) return true;
    if (originalPoints.length !== editPoints.length) return true;
    for (let i = 0; i < originalPoints.length; i++) {
      if (originalPoints[i][0] !== editPoints[i][0] || originalPoints[i][1] !== editPoints[i][1]) {
        return true;
      }
    }
    return false;
  }, [editPoints, editName, selectedPath, isEditing]);

  useEffect(() => {
    // Initial data load on mount. State is set asynchronously after the fetches resolve,
    // so this is the intended fetch-on-mount pattern rather than derivable state.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    loadPaths();
    loadQueue();
  }, [loadPaths, loadQueue]);

  const handleSelectPath = async (path: StairPath) => {
    if (isEditing) return;
    setSelectedPath(path);
    setIsCreating(false);
    setIsEditing(false);
    setPhotos([]);
    setIsLoadingPhotos(true);
    
    try {
      const res = await fetch(`${API_BASE}/stairpaths/${path.id}/photos`);
      const data = await res.json();
      setPhotos(data.map((p: { id: string }) => p.id));
    } catch {
      setError('Could not load photos.');
    } finally {
      setIsLoadingPhotos(false);
    }
  };

  const handleCreateCancel = () => {
    setIsCreating(false);
    setCreateStep(0);
    setCreatePoints([]);
    setNewName('');
  };

  const handleEditClick = () => {
    if (!selectedPath) return;
    setIsEditing(true);
    setEditName(selectedPath.name);
    setEditPoints(parsePoints(selectedPath.pathData, [
      [selectedPath.startLatitude, selectedPath.startLongitude],
      [selectedPath.endLatitude, selectedPath.endLongitude]
    ]));
  };

  const handleSaveEdit = async () => {
    if (!selectedPath || editPoints.length < 2 || !editName.trim()) return;
    const start = editPoints[0];
    const end = editPoints[editPoints.length - 1];
    const payload = {
      ...selectedPath,
      name: editName.trim(),
      startLatitude: start[0],
      startLongitude: start[1],
      endLatitude: end[0],
      endLongitude: end[1],
      pathData: editPoints
    };
    
    try {
      const res = await fetch(`${ADMIN_BASE}/stairpaths/${selectedPath.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      if (!res.ok) throw new Error();
      const updated = await res.json();
      setPaths(prev => prev.map(p => p.id === updated.id ? updated : p));
      setSelectedPath(updated);
      setIsEditing(false);
    } catch {
      setError('Could not save the edit.');
    }
  };

  const handleDeletePath = async () => {
    if (!selectedPath) return;
    if (!confirm(`Delete "${selectedPath.name}" and its photos? This cannot be undone.`)) return;
    try {
      const res = await fetch(`${ADMIN_BASE}/stairpaths/${selectedPath.id}`, { method: 'DELETE' });
      if (!res.ok) throw new Error();
      setPaths(prev => prev.filter(p => p.id !== selectedPath.id));
      setSelectedPath(null);
    } catch {
      setError('Could not delete the path.');
    }
  };

  const handleUploadPhotos = async (files: FileList | null) => {
    if (!selectedPath || !files || files.length === 0) return;
    setIsUploading(true);
    try {
      for (const file of Array.from(files)) {
        const res = await fetch(`${ADMIN_BASE}/stairpaths/${selectedPath.id}/photos`, {
          method: 'POST',
          headers: { 'Content-Type': 'image/jpeg' },
          body: file
        });
        if (!res.ok) throw new Error();
        const { id } = await res.json();
        setPhotos(prev => [...prev, id]);
      }
    } catch {
      setError('Could not upload one or more photos.');
    } finally {
      setIsUploading(false);
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  };

  const reviewSubmission = async (id: number, action: 'approve' | 'reject') => {
    try {
      const res = await fetch(`${ADMIN_BASE}/submissions/${id}/${action}`, { method: 'POST' });
      if (!res.ok) throw new Error();
      setSubmissions(prev => prev.filter(s => s.id !== id));
      if (action === 'approve') loadPaths();
    } catch {
      setError(`Could not ${action} the submission.`);
    }
  };

  const reviewPhoto = async (id: string, action: 'approve' | 'reject') => {
    try {
      const res = await fetch(`${ADMIN_BASE}/photos/${id}/${action}`, { method: 'POST' });
      if (!res.ok) throw new Error();
      setPendingPhotos(prev => prev.filter(p => p.id !== id));
    } catch {
      setError(`Could not ${action} the photo.`);
    }
  };

  const handleDeletePhoto = async (id: string) => {
    try {
      const res = await fetch(`${ADMIN_BASE}/photos/${id}/reject`, { method: 'POST' });
      if (!res.ok) throw new Error();
      setPhotos(prev => prev.filter(p => p !== id));
    } catch {
      setError('Could not delete the photo.');
    }
  };

  const handleSubmitNewPath = async () => {
    if (createPoints.length < 2 || !newName) return;
    
    const start = createPoints[0];
    const end = createPoints[createPoints.length - 1];

    const payload = {
      name: newName,
      startLatitude: start[0],
      startLongitude: start[1],
      endLatitude: end[0],
      endLongitude: end[1],
      pathData: createPoints
    };

    try {
      const res = await fetch(`${ADMIN_BASE}/stairpaths`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      if (!res.ok) throw new Error();
      const newPath = await res.json();
      setPaths(prev => [...prev, newPath]);
      handleCreateCancel();
      handleSelectPath(newPath);
    } catch {
      setError('Could not create the path.');
    }
  };

  return (
    <div className="app-container">
      <header className="header" style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
        <MapPin size={28} color="#e2552b" />
        <h1 style={{ marginRight: 'auto' }}>Stairs &amp; Paths</h1>
        <button
          className={`btn ${view === 'map' ? 'btn-primary' : 'btn-secondary'}`}
          onClick={() => setView('map')}
        >
          <MapPin size={16} /> Map
        </button>
        <button
          className={`btn ${view === 'queue' ? 'btn-primary' : 'btn-secondary'}`}
          onClick={() => { setView('queue'); loadQueue(); }}
        >
          <ClipboardList size={16} /> Review Queue
          {queueCount > 0 && (
            <span style={{ marginLeft: '0.4rem', background: '#e2552b', color: 'white', borderRadius: '999px', padding: '0.05rem 0.5rem', fontSize: '0.75rem', fontWeight: 700 }}>
              {queueCount}
            </span>
          )}
        </button>
        <button
          className="btn btn-secondary"
          onClick={() => { window.location.href = '/cdn-cgi/access/logout'; }}
        >
          <LogOut size={16} /> Log out
        </button>
      </header>

      <AnimatePresence>
        {error && (
          <motion.div
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            onClick={() => setError(null)}
            style={{ background: '#7f1d1d', color: 'white', padding: '0.6rem 1rem', cursor: 'pointer', display: 'flex', justifyContent: 'space-between' }}
          >
            <span>{error}</span>
            <span style={{ opacity: 0.8 }}>Dismiss ✕</span>
          </motion.div>
        )}
      </AnimatePresence>

      {view === 'queue' ? (
        <ReviewQueue
          submissions={submissions}
          pendingPhotos={pendingPhotos}
          paths={paths}
          apiBase={API_BASE}
          onRefresh={loadQueue}
          onReviewSubmission={reviewSubmission}
          onReviewPhoto={reviewPhoto}
        />
      ) : (
      <main className="main-content">
        <aside className="sidebar">
          <div style={{ padding: '1.5rem', borderBottom: '1px solid var(--bg-surface-hover)' }}>
            <button 
              className="btn btn-primary" 
              style={{ width: '100%', justifyContent: 'center' }}
              onClick={() => {
                setIsCreating(true);
                setSelectedPath(null);
                setCreateStep(0);
                setCreatePoints([]);
              }}
            >
              <Plus size={20} /> Add New Path
            </button>
          </div>

          <div style={{ flex: 1, overflowY: 'auto' }}>
            {paths.map(path => (
              <div 
                key={path.id} 
                className={`path-card ${selectedPath?.id === path.id ? 'active' : ''}`}
                onClick={() => handleSelectPath(path)}
              >
                <h3>{path.name}</h3>
                <p>Path #{path.id}</p>
              </div>
            ))}
          </div>
        </aside>

        <section className="map-area">
          <MapContainer 
            center={[37.7749, -122.4194]} 
            zoom={13} 
            style={{ height: '100%', width: '100%', borderRadius: 'var(--border-radius)' }}
          >
            <TileLayer
              attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OSM</a>'
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
              className="map-tiles"
            />
            <MapClickHandler
              enabled={isCreating && createStep === 0}
              onAdd={pt => setCreatePoints(prev => [...prev, pt])}
            />

            {/* Existing Paths */}
            {paths.map(path => {
              if (selectedPath?.id === path.id && isEditing) return null;
              const positions = parsePoints(path.pathData, [
                [path.startLatitude, path.startLongitude],
                [path.endLatitude, path.endLongitude]
              ]);
              return (
                <Polyline
                  key={path.id}
                  positions={positions}
                  color={selectedPath?.id === path.id ? '#a855f7' : '#bf00ff'}
                  weight={selectedPath?.id === path.id ? 10 : 6}
                  opacity={selectedPath?.id === path.id ? 1.0 : 0.85}
                  eventHandlers={{
                    click: () => {
                      if (!isEditing) handleSelectPath(path);
                    }
                  }}
                />
              );
            })}

            {/* Edit Mode Markers and Polyline */}
            {isEditing && selectedPath && (
              <>
                <Polyline positions={editPoints} color="#a855f7" weight={10} />
                {editPoints.map((pt, i) => (
                  <Marker 
                    key={`pt-${i}`} 
                    position={pt} 
                    draggable={true}
                    eventHandlers={{
                      dragend: (e) => {
                        const newPt = [e.target.getLatLng().lat, e.target.getLatLng().lng] as [number, number];
                        setEditPoints(prev => prev.map((p, idx) => idx === i ? newPt : p));
                      }
                    }}
                  />
                ))}
                {editPoints.map((pt, i) => {
                  if (i === editPoints.length - 1) return null;
                  const nextPt = editPoints[i+1];
                  const midPt: [number, number] = [(pt[0] + nextPt[0]) / 2, (pt[1] + nextPt[1]) / 2];
                  return (
                    <Marker 
                      key={`mid-${i}`} 
                      position={midPt} 
                      draggable={true}
                      opacity={0.5}
                      eventHandlers={{
                        dragend: (e) => {
                          const newPt = [e.target.getLatLng().lat, e.target.getLatLng().lng] as [number, number];
                          setEditPoints(prev => {
                            const newArr = [...prev];
                            newArr.splice(i + 1, 0, newPt);
                            return newArr;
                          });
                        }
                      }}
                    />
                  );
                })}
              </>
            )}

            {/* Creation Markers */}
            {isCreating && createStep === 0 && (
              <>
                {createPoints.length > 1 && (
                  <Polyline positions={createPoints} color="#ef4444" weight={4} dashArray="5, 10" />
                )}
                {createPoints.map((pt, i) => (
                  <Marker key={`create-${i}`} position={pt} />
                ))}
              </>
            )}
          </MapContainer>

          {/* Creation Overlay */}
          <AnimatePresence>
            {isCreating && (
              <motion.div 
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: 20 }}
                className="floating-overlay glass-panel"
                style={{ width: '400px', display: 'flex', flexDirection: 'column', gap: '1rem' }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <h3 style={{ margin: 0 }}>Create New Path</h3>
                  <button onClick={handleCreateCancel} style={{ background: 'transparent', border: 'none', color: 'white', cursor: 'pointer' }}>
                    <X size={20} />
                  </button>
                </div>
                
                {createStep === 0 && (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                    <p>Tap the map to add points to the path. Add as many points as you need.</p>
                    <button 
                      className="btn btn-primary" 
                      onClick={() => setCreateStep(1)}
                      disabled={createPoints.length < 2}
                      style={{ opacity: createPoints.length >= 2 ? 1 : 0.5, cursor: createPoints.length >= 2 ? 'pointer' : 'not-allowed' }}
                    >
                      Finish Drawing Path
                    </button>
                  </div>
                )}
                {createStep === 1 && (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                    <input 
                      type="text" 
                      placeholder="Path Name (e.g. Pacheco Stairs)" 
                      value={newName}
                      onChange={e => setNewName(e.target.value)}
                      style={{ padding: '0.75rem', borderRadius: '8px', border: '1px solid #334155', background: '#0f172a', color: 'white' }}
                    />
                    <div style={{ display: 'flex', gap: '0.5rem' }}>
                      <button 
                        className="btn btn-primary" 
                        onClick={handleSubmitNewPath} 
                        disabled={!newName.trim()}
                        style={{ flex: 1, opacity: newName.trim() ? 1 : 0.5, cursor: newName.trim() ? 'pointer' : 'not-allowed' }}
                      >
                        <Check size={18} /> Save Path
                      </button>
                      <button 
                        className="btn btn-secondary" 
                        onClick={() => setCreateStep(0)} 
                        style={{ flex: 1 }}
                      >
                        Back
                      </button>
                    </div>
                  </div>
                )}
              </motion.div>
            )}
          </AnimatePresence>

          {/* Photos Sidebar / Overlay */}
          <AnimatePresence>
            {selectedPath && !isCreating && (
              <motion.div 
                initial={{ opacity: 0, x: 20 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: 20 }}
                className="glass-panel"
                style={{ position: 'absolute', top: '1rem', right: '1rem', width: '320px', zIndex: 1000, maxHeight: 'calc(100% - 2rem)', overflowY: 'auto' }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', flex: 1, minWidth: 0 }}>
                    {!isEditing && <h3 style={{ margin: 0, fontSize: '1.2rem' }}>{selectedPath.name}</h3>}
                    {!isEditing && (
                      <button onClick={handleEditClick} style={{ background: '#3b82f6', border: 'none', color: 'white', cursor: 'pointer', padding: '4px 8px', borderRadius: '4px', fontSize: '0.8rem' }}>
                        Edit Path
                      </button>
                    )}
                  </div>
                  <button onClick={() => { setSelectedPath(null); setIsEditing(false); }} style={{ background: 'transparent', border: 'none', color: 'white', cursor: 'pointer' }}>
                    <X size={20} />
                  </button>
                </div>

                {isEditing ? (
                  <div style={{ padding: '1rem', background: 'rgba(255,255,255,0.1)', borderRadius: '8px', marginBottom: '1rem' }}>
                    <input
                      type="text"
                      placeholder="Path Name"
                      value={editName}
                      onChange={e => setEditName(e.target.value)}
                      style={{ width: '100%', padding: '0.6rem', borderRadius: '8px', border: '1px solid #334155', background: '#0f172a', color: 'white', marginBottom: '1rem', boxSizing: 'border-box' }}
                    />
                    <p style={{ margin: '0 0 1rem 0', fontSize: '0.9rem' }}>Drag markers to move points. Drag translucent midpoint markers to add a new point.</p>
                    <div style={{ display: 'flex', gap: '0.5rem' }}>
                      <button
                        className="btn btn-primary"
                        disabled={!hasChanges || !editName.trim()}
                        onClick={handleSaveEdit}
                        style={{ flex: 1, opacity: (hasChanges && editName.trim()) ? 1 : 0.5, cursor: (hasChanges && editName.trim()) ? 'pointer' : 'not-allowed' }}
                      >
                        Save
                      </button>
                      <button 
                        className="btn btn-secondary" 
                        onClick={() => { setIsEditing(false); handleSelectPath(selectedPath); }} 
                        style={{ flex: 1 }}
                      >
                        Cancel
                      </button>
                    </div>
                  </div>
                ) : (
                  <>
                    <input
                      ref={fileInputRef}
                      type="file"
                      accept="image/*"
                      multiple
                      style={{ display: 'none' }}
                      onChange={e => handleUploadPhotos(e.target.files)}
                    />
                    <div style={{ display: 'flex', gap: '0.5rem', marginBottom: '1rem' }}>
                      <button
                        className="btn btn-primary"
                        style={{ flex: 1, justifyContent: 'center', opacity: isUploading ? 0.6 : 1 }}
                        disabled={isUploading}
                        onClick={() => fileInputRef.current?.click()}
                      >
                        <Upload size={16} /> {isUploading ? 'Uploading…' : 'Add Photos'}
                      </button>
                      <button
                        className="btn btn-secondary"
                        title="Delete path"
                        onClick={handleDeletePath}
                        style={{ color: '#fca5a5' }}
                      >
                        <Trash2 size={16} />
                      </button>
                    </div>
                    {isLoadingPhotos ? (
                      <div style={{ padding: '2rem', textAlign: 'center' }}>Loading photos...</div>
                    ) : photos.length === 0 ? (
                      <div style={{ textAlign: 'center', padding: '2rem 0', color: 'var(--text-muted)' }}>
                        <ImageIcon size={48} style={{ opacity: 0.5, marginBottom: '1rem' }} />
                        <p>No photos yet</p>
                      </div>
                    ) : (
                      <div className="photo-grid">
                        {photos.map(id => (
                          <div key={id} style={{ position: 'relative' }} className="animate-fade-in">
                            <img
                              src={`${API_BASE}/photos/${id}`}
                              alt="Stairway"
                              className="photo-item"
                            />
                            <button
                              title="Delete photo"
                              onClick={() => handleDeletePhoto(id)}
                              style={{ position: 'absolute', top: 4, right: 4, background: 'rgba(0,0,0,0.6)', border: 'none', color: 'white', borderRadius: '6px', padding: '3px', cursor: 'pointer', display: 'flex' }}
                            >
                              <Trash2 size={14} />
                            </button>
                          </div>
                        ))}
                      </div>
                    )}
                  </>
                )}
              </motion.div>
            )}
          </AnimatePresence>
        </section>
      </main>
      )}
    </div>
  );
}

function MapClickHandler({ enabled, onAdd }: { enabled: boolean; onAdd: (pt: [number, number]) => void }) {
  useMapEvents({
    click(e) {
      if (!enabled) return;
      onAdd([e.latlng.lat, e.latlng.lng]);
    }
  });
  return null;
}

function FitBounds({ points }: { points: [number, number][] }) {
  const map = useMap();
  useEffect(() => {
    if (points.length > 0) {
      map.fitBounds(L.latLngBounds(points as L.LatLngExpression[]).pad(0.3));
    }
  }, [map, points]);
  return null;
}

function SubmissionCard({
  submission,
  existing,
  onReview,
}: {
  submission: Submission;
  existing?: StairPath;
  onReview: (id: number, action: 'approve' | 'reject') => void;
}) {
  const payload = useMemo(() => {
    try {
      return JSON.parse(submission.payload) as {
        name: string;
        startLatitude: number;
        startLongitude: number;
        endLatitude: number;
        endLongitude: number;
        pathData?: [number, number][];
      };
    } catch {
      return null;
    }
  }, [submission.payload]);

  if (!payload) return null;

  const newPoints: [number, number][] = payload.pathData ?? [
    [payload.startLatitude, payload.startLongitude],
    [payload.endLatitude, payload.endLongitude],
  ];
  const oldPoints = existing
    ? parsePoints(existing.pathData, [
        [existing.startLatitude, existing.startLongitude],
        [existing.endLatitude, existing.endLongitude],
      ])
    : [];

  return (
    <div className="glass-panel" style={{ padding: '1rem', display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
        <h3 style={{ margin: 0 }}>{payload.name}</h3>
        <span style={{ fontSize: '0.75rem', textTransform: 'uppercase', letterSpacing: '0.05em', color: submission.kind === 'create' ? '#34d399' : '#fbbf24' }}>
          {submission.kind === 'create' ? 'New path' : `Edit · #${submission.target_id}`}
        </span>
      </div>
      <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>
        {newPoints.length} points{submission.submitter ? ` · by ${submission.submitter}` : ''} · {new Date(submission.created_at + 'Z').toLocaleString()}
      </div>
      <MapContainer center={newPoints[0]} zoom={15} style={{ height: '160px', width: '100%', borderRadius: '8px' }} scrollWheelZoom={false}>
        <TileLayer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
        {oldPoints.length > 0 && <Polyline positions={oldPoints} color="#64748b" weight={4} dashArray="4,6" />}
        <Polyline positions={newPoints} color="#bf00ff" weight={6} />
        <FitBounds points={[...newPoints, ...oldPoints]} />
      </MapContainer>
      {existing && (
        <div style={{ fontSize: '0.72rem', color: 'var(--text-muted)' }}>
          <span style={{ color: '#94a3b8' }}>— —</span> current · <span style={{ color: '#bf00ff' }}>———</span> proposed
        </div>
      )}
      <div style={{ display: 'flex', gap: '0.5rem' }}>
        <button className="btn btn-primary" style={{ flex: 1, justifyContent: 'center' }} onClick={() => onReview(submission.id, 'approve')}>
          <Check size={16} /> Approve
        </button>
        <button className="btn btn-secondary" style={{ flex: 1, justifyContent: 'center', color: '#fca5a5' }} onClick={() => onReview(submission.id, 'reject')}>
          <X size={16} /> Reject
        </button>
      </div>
    </div>
  );
}

function ReviewQueue({
  submissions,
  pendingPhotos,
  paths,
  apiBase,
  onRefresh,
  onReviewSubmission,
  onReviewPhoto,
}: {
  submissions: Submission[];
  pendingPhotos: PendingPhoto[];
  paths: StairPath[];
  apiBase: string;
  onRefresh: () => void;
  onReviewSubmission: (id: number, action: 'approve' | 'reject') => void;
  onReviewPhoto: (id: string, action: 'approve' | 'reject') => void;
}) {
  const isEmpty = submissions.length === 0 && pendingPhotos.length === 0;

  return (
    <div style={{ flex: 1, overflowY: 'auto', padding: '1.5rem' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '1rem' }}>
        <h2 style={{ margin: 0 }}>Review Queue</h2>
        <button className="btn btn-secondary" onClick={onRefresh}><RefreshCw size={16} /> Refresh</button>
      </div>

      {isEmpty && (
        <div style={{ textAlign: 'center', padding: '4rem 0', color: 'var(--text-muted)' }}>
          <Check size={48} style={{ opacity: 0.5, marginBottom: '1rem' }} />
          <p>Nothing to review. You're all caught up.</p>
        </div>
      )}

      {submissions.length > 0 && (
        <section style={{ marginBottom: '2rem' }}>
          <h3 style={{ color: 'var(--text-muted)', fontSize: '0.9rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
            Path submissions ({submissions.length})
          </h3>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))', gap: '1rem' }}>
            {submissions.map(s => (
              <SubmissionCard
                key={s.id}
                submission={s}
                existing={s.target_id ? paths.find(p => p.id === s.target_id) : undefined}
                onReview={onReviewSubmission}
              />
            ))}
          </div>
        </section>
      )}

      {pendingPhotos.length > 0 && (
        <section>
          <h3 style={{ color: 'var(--text-muted)', fontSize: '0.9rem', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
            Photo submissions ({pendingPhotos.length})
          </h3>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', gap: '1rem' }}>
            {pendingPhotos.map(photo => (
              <div key={photo.id} className="glass-panel" style={{ padding: '0.75rem', display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                <img src={`${apiBase}/photos/${photo.id}`} alt="Pending submission" style={{ width: '100%', height: '180px', objectFit: 'cover', borderRadius: '8px' }} />
                <div style={{ fontSize: '0.8rem', color: 'var(--text-muted)' }}>{photo.stairpath_name ?? `Path #${photo.stairpath_id}`}</div>
                <div style={{ display: 'flex', gap: '0.5rem' }}>
                  <button className="btn btn-primary" style={{ flex: 1, justifyContent: 'center' }} onClick={() => onReviewPhoto(photo.id, 'approve')}>
                    <Check size={16} /> Approve
                  </button>
                  <button className="btn btn-secondary" style={{ flex: 1, justifyContent: 'center', color: '#fca5a5' }} onClick={() => onReviewPhoto(photo.id, 'reject')}>
                    <X size={16} /> Reject
                  </button>
                </div>
              </div>
            ))}
          </div>
        </section>
      )}
    </div>
  );
}
