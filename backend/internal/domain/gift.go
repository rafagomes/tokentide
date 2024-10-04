package domain

type Gift struct {
	ID       string  `json:"id"`
	Name     string  `json:"name"`
	Price    float64 `json:"price"`
	ArtistID string  `json:"artist_id"`
}

// GiftRepository is the interface for database operations
type GiftRepository interface {
	CreateGift(gift Gift) error
	GetGiftByID(id string) (*Gift, error)
}

// GiftService is the interface for business logic operations
type GiftService interface {
	CreateGift(gift Gift) error
	GetGiftByID(id string) (*Gift, error)
}
