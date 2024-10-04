package service

import (
	"tokentide/internal/domain"
)

type GiftServiceImpl struct {
	repo domain.GiftRepository
}

func NewGiftService(repo domain.GiftRepository) domain.GiftService {
	return &GiftServiceImpl{repo: repo}
}

func (s *GiftServiceImpl) CreateGift(gift domain.Gift) error {
	return s.repo.CreateGift(gift)
}

func (s *GiftServiceImpl) GetGiftByID(id string) (*domain.Gift, error) {
	return s.repo.GetGiftByID(id)
}
