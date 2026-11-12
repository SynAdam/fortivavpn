package agent

import (
	"bytes"
	"crypto/rand"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"syscall"
	"time"
)

// Store keeps what the agent must remember across a restart, in one
// directory: the device id, the last doors the backend sent, the door that
// last worked and whether the person paused the tunnel. A router's flash
// wears out, so a file is written only when what it holds changed.
type Store struct {
	dir string
	mu  sync.Mutex
}

// NewStore uses dir, creating it.
func NewStore(dir string) (*Store, error) {
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return nil, err
	}
	return &Store{dir: dir}, nil
}

const (
	deviceFile  = "device.json"
	configsFile = "configs.json"
	memoryFile  = "memory.json"
)

type deviceRecord struct {
	DeviceID  string    `json:"device_id"`
	CreatedAt time.Time `json:"created_at"`
}

// DeviceID returns the router's id, made on the first call. It is a random
// UUID, as the app makes when the platform gives it no install id. The
// package keeps the file through a firmware upgrade (lib/upgrade/keep.d),
// so an upgraded router stays the same device with the same allowance and
// Premium.
func (s *Store) DeviceID() (string, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var rec deviceRecord
	if err := s.read(deviceFile, &rec); err == nil && validUUID(rec.DeviceID) {
		return rec.DeviceID, nil
	}
	id, err := newUUID()
	if err != nil {
		return "", err
	}
	rec = deviceRecord{DeviceID: id, CreatedAt: time.Now().UTC()}
	if err := s.write(deviceFile, rec); err != nil {
		return "", err
	}
	return id, nil
}

// Memory is the small state the agent learns as it runs.
type Memory struct {
	// Paused is true while the person has turned the tunnel off.
	Paused bool `json:"paused,omitempty"`
	// LastDoor is the door that last carried a tunnel, by server and
	// inbound, which the next search tries first.
	LastDoor *DoorKey `json:"last_door,omitempty"`
	// Relays is the backend's list from /app/config.
	Relays []Relay `json:"relays,omitempty"`
}

// DoorKey names one door of one server.
type DoorKey struct {
	ServerID  int `json:"server_id"`
	InboundID int `json:"inbound_id"`
}

// LoadMemory returns what was saved, or nothing.
func (s *Store) LoadMemory() Memory {
	s.mu.Lock()
	defer s.mu.Unlock()
	var m Memory
	_ = s.read(memoryFile, &m)
	return m
}

// SaveMemory writes m when it differs from what is on disk.
func (s *Store) SaveMemory(m Memory) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.write(memoryFile, m)
}

// LoadConfigs returns the last doors the backend sent, so a router that
// restarts while the backend cannot be reached still connects.
func (s *Store) LoadConfigs() (*Configs, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	var c Configs
	if err := s.read(configsFile, &c); err != nil {
		return nil, err
	}
	return &c, nil
}

// SaveConfigs keeps c for the next start.
func (s *Store) SaveConfigs(c *Configs) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.write(configsFile, c)
}

func (s *Store) read(name string, v any) error {
	data, err := os.ReadFile(filepath.Join(s.dir, name))
	if err != nil {
		return err
	}
	return json.Unmarshal(data, v)
}

// write replaces name atomically, and not at all when it would not change.
// The new file is synced before the rename and the directory after it. A
// router's flash (UBIFS, JFFS2) writes back late, and a power cut soon after
// an unsynced rename can leave the file empty.
func (s *Store) write(name string, v any) error {
	data, err := json.MarshalIndent(v, "", " ")
	if err != nil {
		return err
	}
	path := filepath.Join(s.dir, name)
	if old, err := os.ReadFile(path); err == nil && bytes.Equal(old, data) {
		return nil
	}
	tmp := path + ".tmp"
	f, err := os.OpenFile(tmp, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o600)
	if err != nil {
		return err
	}
	_, err = f.Write(data)
	if err == nil {
		err = syncFile(f)
	}
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	if err != nil {
		os.Remove(tmp)
		return err
	}
	if err := os.Rename(tmp, path); err != nil {
		return err
	}
	return syncDir(s.dir)
}

// syncFile and syncDir flush a file and a directory to the flash. A test
// replaces them to see the order.
var (
	syncFile = (*os.File).Sync
	syncDir  = func(dir string) error {
		d, err := os.Open(dir)
		if err != nil {
			return err
		}
		defer d.Close()
		// Some file systems cannot sync a directory. The file itself is
		// synced by then, so that is not a reason to fail the write.
		if err := d.Sync(); err != nil && !errors.Is(err, syscall.EINVAL) && !errors.Is(err, syscall.ENOTSUP) {
			return err
		}
		return nil
	}
)

func newUUID() (string, error) {
	var b [16]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "", err
	}
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", b[0:4], b[4:6], b[6:8], b[8:10], b[10:16]), nil
}

func validUUID(s string) bool {
	if len(s) != 36 {
		return false
	}
	for i, c := range s {
		switch i {
		case 8, 13, 18, 23:
			if c != '-' {
				return false
			}
		default:
			if !(c >= '0' && c <= '9' || c >= 'a' && c <= 'f') {
				return false
			}
		}
	}
	return true
}

var errNoConfigs = errors.New("no doors")
