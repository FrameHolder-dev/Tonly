package model

type NFTItem struct {
	Address        string  `json:"address"`
	Name           string  `json:"name"`
	Description    string  `json:"description"`
	ImageURL       string  `json:"image_url"`
	AnimationURL   string  `json:"animation_url,omitempty"`
	CollectionName string  `json:"collection_name"`
	CollectionAddr string  `json:"collection_address"`
	Verified       bool    `json:"verified"`
	FloorPrice     float64 `json:"floor_price"`
	DNS            string  `json:"dns,omitempty"`
	NFTType        string  `json:"nft_type"`
}
