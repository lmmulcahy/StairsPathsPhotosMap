import { useState, useEffect } from 'react';
import { MapContainer, TileLayer, Polyline, Marker, useMapEvents } from 'react-leaflet';
import { MapPin, Plus, X, Image as ImageIcon, Check } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import L from 'leaflet';

// Fix Leaflet default marker icon issue in Vite
delete (L.Icon.Default.prototype as any)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
});

const API_BASE = 'https://stairs-paths-api.luke-mulcahy.workers.dev';

interface StairPath {
  id: number;
  name: string;
  startLatitude: number;
  startLongitude: number;
  endLatitude: number;
  endLongitude: number;
  pathData?: string;
}

export default function App() {
  const [paths, setPaths] = useState<StairPath[]>([]);
  const [selectedPath, setSelectedPath] = useState<StairPath | null>(null);
  const [photos, setPhotos] = useState<string[]>([]);
  const [isLoadingPhotos, setIsLoadingPhotos] = useState(false);
  
  // Creation state
  const [isCreating, setIsCreating] = useState(false);
  const [createStep, setCreateStep] = useState<0|1|2>(0);
  const [startPoint, setStartPoint] = useState<[number, number] | null>(null);
  const [endPoint, setEndPoint] = useState<[number, number] | null>(null);
  const [newName, setNewName] = useState('');

  // Edit state
  const [isEditing, setIsEditing] = useState(false);
  const [editPoints, setEditPoints] = useState<[number, number][]>([]);

  useEffect(() => {
    fetch(`${API_BASE}/stairpaths`)
      .then(res => res.json())
      .then(data => setPaths(data))
      .catch(console.error);
  }, []);

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
      setPhotos(data.map((p: any) => p.id));
    } catch (e) {
      console.error(e);
    } finally {
      setIsLoadingPhotos(false);
    }
  };

  const handleCreateCancel = () => {
    setIsCreating(false);
    setCreateStep(0);
    setStartPoint(null);
    setEndPoint(null);
    setNewName('');
  };

  const handleEditClick = () => {
    if (!selectedPath) return;
    setIsEditing(true);
    if (selectedPath.pathData) {
      try {
        setEditPoints(typeof selectedPath.pathData === 'string' ? JSON.parse(selectedPath.pathData) : selectedPath.pathData);
      } catch {
        setEditPoints([
          [selectedPath.startLatitude, selectedPath.startLongitude],
          [selectedPath.endLatitude, selectedPath.endLongitude]
        ]);
      }
    } else {
      setEditPoints([
        [selectedPath.startLatitude, selectedPath.startLongitude],
        [selectedPath.endLatitude, selectedPath.endLongitude]
      ]);
    }
  };

  const handleSaveEdit = async () => {
    if (!selectedPath || editPoints.length < 2) return;
    const start = editPoints[0];
    const end = editPoints[editPoints.length - 1];
    const payload = {
      ...selectedPath,
      startLatitude: start[0],
      startLongitude: start[1],
      endLatitude: end[0],
      endLongitude: end[1],
      pathData: editPoints
    };
    
    try {
      const res = await fetch(`${API_BASE}/stairpaths/${selectedPath.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      const updated = await res.json();
      setPaths(prev => prev.map(p => p.id === updated.id ? updated : p));
      setSelectedPath(updated);
      setIsEditing(false);
    } catch (e) {
      console.error(e);
    }
  };

  const handleSubmitNewPath = async () => {
    if (!startPoint || !endPoint || !newName) return;
    
    const payload = {
      name: newName,
      startLatitude: startPoint[0],
      startLongitude: startPoint[1],
      endLatitude: endPoint[0],
      endLongitude: endPoint[1]
    };

    try {
      const res = await fetch(`${API_BASE}/stairpaths`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      const newPath = await res.json();
      setPaths(prev => [...prev, newPath]);
      handleCreateCancel();
      handleSelectPath(newPath);
    } catch (e) {
      console.error(e);
    }
  };

  // Map Click Handler Component
  function MapClickHandler() {
    useMapEvents({
      click(e) {
        if (!isCreating) return;
        if (createStep === 0) {
          setStartPoint([e.latlng.lat, e.latlng.lng]);
          setCreateStep(1);
        } else if (createStep === 1) {
          setEndPoint([e.latlng.lat, e.latlng.lng]);
          setCreateStep(2);
        }
      }
    });
    return null;
  }

  return (
    <div className="app-container">
      <header className="header">
        <MapPin size={28} color="#3b82f6" />
        <h1>Stairs & Paths</h1>
      </header>

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
                setStartPoint(null);
                setEndPoint(null);
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
            <MapClickHandler />

            {/* Existing Paths */}
            {paths.map(path => {
              if (selectedPath?.id === path.id && isEditing) return null;
              let positions: [number, number][] = [
                [path.startLatitude, path.startLongitude],
                [path.endLatitude, path.endLongitude]
              ];
              if (path.pathData) {
                 try {
                    positions = typeof path.pathData === 'string' ? JSON.parse(path.pathData) : path.pathData;
                 } catch {}
              }
              return (
                <Polyline 
                  key={path.id}
                  positions={positions}
                  color={selectedPath?.id === path.id ? '#a855f7' : '#ef4444'}
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
            {startPoint && <Marker position={startPoint} />}
            {endPoint && <Marker position={endPoint} />}
            {startPoint && endPoint && (
              <Polyline positions={[startPoint, endPoint]} color="#ef4444" weight={4} dashArray="5, 10" />
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
                
                {createStep === 0 && <p>Tap the map to set the <strong>start</strong> point.</p>}
                {createStep === 1 && <p>Tap the map to set the <strong>end</strong> point.</p>}
                {createStep === 2 && (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                    <input 
                      type="text" 
                      placeholder="Path Name (e.g. Pacheco Stairs)" 
                      value={newName}
                      onChange={e => setNewName(e.target.value)}
                      style={{ padding: '0.75rem', borderRadius: '8px', border: '1px solid #334155', background: '#0f172a', color: 'white' }}
                    />
                    <button className="btn btn-primary" onClick={handleSubmitNewPath}>
                      <Check size={18} /> Save Path
                    </button>
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
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                    <h3 style={{ margin: 0, fontSize: '1.2rem' }}>{selectedPath.name}</h3>
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
                    <p style={{ margin: '0 0 1rem 0', fontSize: '0.9rem' }}>Drag markers to move points. Drag translucent midpoint markers to add a new point.</p>
                    <div style={{ display: 'flex', gap: '0.5rem' }}>
                      <button className="btn btn-primary" onClick={handleSaveEdit} style={{ flex: 1 }}>Save</button>
                      <button className="btn" onClick={() => { setIsEditing(false); handleSelectPath(selectedPath); }} style={{ flex: 1, background: '#475569' }}>Cancel</button>
                    </div>
                  </div>
                ) : (
                  <>
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
                          <img 
                            key={id} 
                            src={`${API_BASE}/photos/${id}`} 
                            alt="Stairway" 
                            className="photo-item animate-fade-in" 
                          />
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
    </div>
  );
}
