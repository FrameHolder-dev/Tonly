package service

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/ecdh"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"io"
)

type EntropyRequest struct {
	ClientPublicKey string `json:"client_public_key"`
}

type EntropyResponse struct {
	EncryptedEntropy string `json:"encrypted_entropy"`
	ServerPublicKey  string `json:"server_public_key"`
	Nonce            string `json:"nonce"`
}

func GenerateEncryptedEntropy(clientPubKeyBase64 string) (*EntropyResponse, error) {
	clientPubBytes, err := base64.StdEncoding.DecodeString(clientPubKeyBase64)
	if err != nil {
		return nil, fmt.Errorf("invalid client public key: %w", err)
	}

	curve := ecdh.X25519()
	clientPub, err := curve.NewPublicKey(clientPubBytes)
	if err != nil {
		return nil, fmt.Errorf("invalid X25519 public key: %w", err)
	}

	serverPriv, err := curve.GenerateKey(rand.Reader)
	if err != nil {
		return nil, fmt.Errorf("failed to generate server key: %w", err)
	}

	sharedSecret, err := serverPriv.ECDH(clientPub)
	if err != nil {
		return nil, fmt.Errorf("ECDH failed: %w", err)
	}

	aesKey := deriveAESKey(sharedSecret)

	entropy := make([]byte, 256)
	if _, err := io.ReadFull(rand.Reader, entropy); err != nil {
		return nil, fmt.Errorf("entropy generation failed: %w", err)
	}

	block, err := aes.NewCipher(aesKey)
	if err != nil {
		return nil, fmt.Errorf("aes cipher failed: %w", err)
	}

	aesGCM, err := cipher.NewGCM(block)
	if err != nil {
		return nil, fmt.Errorf("gcm failed: %w", err)
	}

	nonce := make([]byte, aesGCM.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, fmt.Errorf("nonce generation failed: %w", err)
	}

	ciphertext := aesGCM.Seal(nil, nonce, entropy, nil)

	return &EntropyResponse{
		EncryptedEntropy: base64.StdEncoding.EncodeToString(ciphertext),
		ServerPublicKey:  base64.StdEncoding.EncodeToString(serverPriv.PublicKey().Bytes()),
		Nonce:            base64.StdEncoding.EncodeToString(nonce),
	}, nil
}

func deriveAESKey(sharedSecret []byte) []byte {
	h := sha256.New()
	h.Write(sharedSecret)
	h.Write([]byte("tonly-entropy-v1"))
	return h.Sum(nil)
}
