package service

import (
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"strings"
)

func TONAddressToRaw(address string) (string, error) {
	address = strings.TrimSpace(address)
	if strings.HasPrefix(address, "0:") || strings.HasPrefix(address, "-1:") {
		return address, nil
	}

	padded := strings.ReplaceAll(strings.ReplaceAll(address, "-", "+"), "_", "/")
	for len(padded)%4 != 0 {
		padded += "="
	}

	raw, err := base64.StdEncoding.DecodeString(padded)
	if err != nil {
		return "", fmt.Errorf("invalid base64: %w", err)
	}
	if len(raw) != 36 {
		return "", fmt.Errorf("invalid address length: %d", len(raw))
	}

	workchain := int8(raw[1])
	hash := hex.EncodeToString(raw[2:34])
	return fmt.Sprintf("%d:%s", workchain, hash), nil
}
