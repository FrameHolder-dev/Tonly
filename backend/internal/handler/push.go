package handler

import (
	"bytes"
	"crypto/ecdsa"
	"crypto/rand"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/json"
	"encoding/pem"
	"fmt"
	"net/http"
	"os"
	"sync"
	"time"
)

type TransactionMonitorInterface interface {
	Watch(address string)
}

type Push struct {
	mu      sync.RWMutex
	devices map[string]DeviceRegistration
	key     *ecdsa.PrivateKey
	keyID   string
	teamID  string
	monitor TransactionMonitorInterface
}

type DeviceRegistration struct {
	Token   string `json:"token"`
	Address string `json:"address"`
	Created time.Time
}

type RegisterRequest struct {
	Token   string `json:"token"`
	Address string `json:"address"`
}

func NewPush() *Push {
	p := &Push{
		devices: make(map[string]DeviceRegistration),
		keyID:   "65ZS89TKRM",
		teamID:  "SDL7K9875S",
	}

	keyData, err := os.ReadFile("/opt/tonly/backend/AuthKey_65ZS89TKRM.p8")
	if err != nil {
		fmt.Printf("push: failed to read APNs key: %v\n", err)
		return p
	}

	block, _ := pem.Decode(keyData)
	if block == nil {
		fmt.Println("push: failed to decode PEM block")
		return p
	}

	parsedKey, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		fmt.Printf("push: failed to parse key: %v\n", err)
		return p
	}

	ecKey, ok := parsedKey.(*ecdsa.PrivateKey)
	if !ok {
		fmt.Println("push: key is not ECDSA")
		return p
	}

	p.key = ecKey
	fmt.Println("push: APNs key loaded")
	return p
}

func (p *Push) SetMonitor(m TransactionMonitorInterface) {
	p.monitor = m
}

func (p *Push) Register(w http.ResponseWriter, r *http.Request) {
	var req RegisterRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Token == "" {
		writeError(w, http.StatusBadRequest, "token is required")
		return
	}

	p.mu.Lock()
	p.devices[req.Token] = DeviceRegistration{
		Token:   req.Token,
		Address: req.Address,
		Created: time.Now(),
	}
	p.mu.Unlock()

	if p.monitor != nil && req.Address != "" {
		p.monitor.Watch(req.Address)
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "registered"})
}

func (p *Push) SendToAddress(address, title, body string) error {
	if p.key == nil {
		return fmt.Errorf("APNs key not loaded")
	}

	p.mu.RLock()
	var tokens []string
	for _, d := range p.devices {
		if d.Address == address {
			tokens = append(tokens, d.Token)
		}
	}
	p.mu.RUnlock()

	for _, token := range tokens {
		if err := p.sendPush(token, title, body); err != nil {
			fmt.Printf("push: failed to send to %s: %v\n", token[:8], err)
		}
	}
	return nil
}

func b64url(data []byte) string {
	return base64.RawURLEncoding.EncodeToString(data)
}

func (p *Push) generateJWT() (string, error) {
	header, _ := json.Marshal(map[string]string{
		"alg": "ES256",
		"kid": p.keyID,
	})

	claims, _ := json.Marshal(map[string]any{
		"iss": p.teamID,
		"iat": time.Now().Unix(),
	})

	signingInput := b64url(header) + "." + b64url(claims)

	hash := sha256.Sum256([]byte(signingInput))
	r, s, err := ecdsa.Sign(rand.Reader, p.key, hash[:])
	if err != nil {
		return "", err
	}

	curveBits := p.key.Curve.Params().BitSize
	keyBytes := curveBits / 8
	if curveBits%8 > 0 {
		keyBytes++
	}

	rBytes := r.Bytes()
	sBytes := s.Bytes()
	sig := make([]byte, 2*keyBytes)
	copy(sig[keyBytes-len(rBytes):keyBytes], rBytes)
	copy(sig[2*keyBytes-len(sBytes):], sBytes)

	return signingInput + "." + b64url(sig), nil
}

func (p *Push) sendPush(deviceToken, title, body string) error {
	token, err := p.generateJWT()
	if err != nil {
		return err
	}

	payload := map[string]any{
		"aps": map[string]any{
			"alert": map[string]string{
				"title": title,
				"body":  body,
			},
			"sound": "default",
		},
	}

	payloadBytes, _ := json.Marshal(payload)

	url := fmt.Sprintf("https://api.sandbox.push.apple.com/3/device/%s", deviceToken)
	req, _ := http.NewRequest("POST", url, bytes.NewReader(payloadBytes))
	req.Header.Set("Authorization", "bearer "+token)
	req.Header.Set("apns-topic", "one.tonly.app")
	req.Header.Set("apns-push-type", "alert")
	req.Header.Set("apns-priority", "10")

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return fmt.Errorf("APNs returned %d", resp.StatusCode)
	}
	return nil
}
