module monkeo::market_event {
    use sui::object::ID;
    use sui::event;

    friend monkeo::market;

    struct MarketCreatedEvent has copy, drop {
        market_id: ID,
        owner: address,
    }

    struct CollectionCreatedEvent has copy, drop {
        collection_id: ID,
        creator_address: address
    }

    struct ItemListedEvent has copy, drop {
        collection_id: ID,
        item_id: ID,
        seller: address,
        price: u64,
    }

    struct ItemPurchasedEvent has copy, drop {
        collection_id: ID,
        item_id: ID,
        seller: address,
        price: u64,

    }

    struct ItemDeListedEvent has copy, drop {
        collection_id: ID,
        item_id: ID,
        listing_id: ID,
        operator: address,
        price: u64,

    }

    struct ItemAdjustPriceEvent has copy, drop {
        collection_id: ID,
        listing_id: ID,
        operator: address,
        price: u64,
    }

    struct PoolCreatedEvent has copy, drop {
        pool_type: bool,
        author: address,
    }

    public(friend) fun market_created_event(
      	market_id: ID,
    	owner: address
    ) {
        event::emit(MarketCreatedEvent {
            market_id,
            owner
        })
    }

    public(friend) fun collection_created_event(
		collection_id: ID,
		creator_address: address
	) {
        event::emit(CollectionCreatedEvent {
            collection_id,
            creator_address
        })
    }

    public(friend) fun item_list_event(
		collection_id: ID,
		item_id: ID,
		seller: address,
		price: u64
	) {
        event::emit(ItemListedEvent {
            collection_id,
            item_id,
            seller,
            price
        })
    }

    public(friend) fun item_puchased_event(
		collection_id: ID,
		item_id: ID,
		seller: address,
		price: u64
    ) {
        event::emit(ItemPurchasedEvent {
            collection_id,
            item_id,
            seller,
            price
        })
    }

    public(friend) fun item_delisted_event(
		collection_id: ID,
		item_id: ID,
		listing_id: ID,
		operator: address,
		price: u64
	) {
        event::emit(ItemDeListedEvent {
            collection_id,
            item_id,
            listing_id,
            operator,
            price,
        })
    }

    public(friend) fun item_adjust_price_event(
      	collection_id: ID,
		listing_id: ID,
		operator: address,
		price: u64
	) {
        event::emit(ItemAdjustPriceEvent {
            collection_id,
            listing_id,
            operator,
            price
        })
    }

    public(friend) fun pool_created_event(
      	pool_type: bool,
		author: address,
	) {
        event::emit(PoolCreatedEvent {
            pool_type,
            author,
        })
    }
}