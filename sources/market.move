module hero::market {
  	use std::ascii::String;
  	use std::type_name::{into_string, get};
    use std::vector;
  
  	use sui::balance::{Self, Balance, zero};
    use sui::coin::{Self, Coin};
    use sui::event::emit;
    use sui::object::{Self, UID, ID};
    use sui::object_table::{Self, ObjectTable};
    use sui::dynamic_object_field as ofield;
    use std::option::{Self, Option};
    use sui::sui::SUI;
    use sui::pay;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    // ======= Event =======
    use hero::market_event;

	// ======= Error =======

	// For when someone tries to delist without ownership.
    const ERR_NOT_OWNER: u64 = 0;
    // For when amount paid does not match the expected.
    const ERR_AMOUNT_INCORRECT: u64 = 1;
    const ERR_EXCEED_NFT: u64 = 2;
    const EAmountZero: u64 = 3;
    const EOwnerAuth: u64 = 4;
    const EObjectNotExist: u64 = 5;
    const EAlreadyExistCollectionType: u64 = 6;

	// ======= Types =======

    struct Listing<phantom Item: store + key> has store, key {
        id: UID,
        price: u64,
        owner: address
    }

    struct WithdrawMarket has key {
        id: UID,
    }

	/// A Capability for market manager.
    struct Marketplace has key {
        id: UID,
        buy_pools: vector<ID>,
        sell_pools: vector<ID>,
    }

    /// A Buy pool
    struct BuyPool has key, store {
        id: UID,
        owner: address,
        spot_price: u64,
        curve_type: bool,
        delta: u64,
        number_of_nfts: u64,
        funds: Coin<SUI>,
        bought: u64
    }

    /// A Sell pool
    struct SellPool has key, store {
        id: UID,
        owner: address,
        spot_price: u64,
        curve_type: bool,
        delta: u64,
        sold: u64
    }

    /// A Liquidity pool
    struct LiquidityPool<phantom T> has key, store {
        id: UID,
        owner: address,
        fee: u64,
        spot_price: u64,
        curve_type: bool,
        delta: u64,
        number_of_nfts: u64,
        // nfts_for_sale: vector<>
    }

	// ======= Publishing =======

    fun init(ctx: &mut TxContext) {
		let market = Marketplace {
            id: object::new(ctx),
            buy_pools: vector::empty(),
            sell_pools: vector::empty(),
        };
		market_event::market_created_event(object::id(&market), tx_context::sender(ctx));
        transfer::share_object(market)
    }

	// ======= Actions =======

    public entry fun create_buy_pool<Item:key+store>(
        market: &mut Marketplace,
        spot_price: u64,
        curve_type: bool,
        delta: u64,
        number_of_nfts: u64,
        paid: Coin<SUI>,
        ctx: &mut TxContext
    ) {
        let id = object::new(ctx);
        let owner = tx_context::sender(ctx);

        let sum = 0;
        let price = spot_price;
        let i = 0;
        while(i < number_of_nfts) {
            if(curve_type){
                price = price * (100 - delta) / 100;
                
            } else {
                price = price - delta;
            };
            sum = sum + price;
            i = i + 1;
        };

        assert!(coin::value(&paid) >= sum, ERR_AMOUNT_INCORRECT);

        let pool = BuyPool{
            id,
            owner,
            spot_price,
            curve_type,
            delta,
            number_of_nfts,
            funds: paid,
            bought: 0
        };
        let pool_id = object::id(&pool);

        vector::push_back(&mut market.buy_pools, object::id(&pool));
        ofield::add(&mut market.id, pool_id, pool);
    }

	public entry fun create_sell_pool<Item:key+store>(
        market: &mut Marketplace,
        spot_price: u64,
        curve_type: bool,
        delta: u64,
        nfts_for_sale: vector<Item>,
        ctx: &mut TxContext
    ) {
        let id = object::new(ctx);
        let owner = tx_context::sender(ctx);
        let length = vector::length<Item>(&nfts_for_sale);

        let i = 0;
        while(i < length) {
            let item = vector::pop_back<Item>(&mut nfts_for_sale);
            let item_id = object::id(&item);
            ofield::add(&mut id, item_id, item);
            i = i + 1;
        };

        let pool = SellPool{
            id,
            owner,
            spot_price,
            curve_type,
            delta,
            sold: 0
        };
        let pool_id = object::id(&pool);

        vector::destroy_empty(nfts_for_sale);
        vector::push_back(&mut market.sell_pools, object::id(&pool));
        ofield::add(&mut market.id, pool_id, pool);
    }

    public entry fun buy_and_take<Item: store+key>(
        market: &mut Marketplace, 
        pool_id: ID,
        item_id: ID,
        paid: Coin<SUI>, 
        ctx: &mut TxContext
    ) {
        transfer::transfer(buy<Item>(market, pool_id, item_id, paid, ctx), tx_context::sender(ctx))
    }

    public entry fun sell_and_take<Item: store+key>(){}

    public entry fun list<Item: store+key>(
        market: &mut Marketplace,
        pool_id: ID,
        item: Item,
        ctx: &mut TxContext
    ) {
        let pool = ofield::borrow_mut<ID, BuyPool>(&mut market.id, pool_id);
        assert!(pool.number_of_nfts >= (pool.bought + 1), ERR_EXCEED_NFT);

        let price = pool.spot_price;
        let i = 0;
        while(i < pool.bought) {
            if(pool.curve_type){
                price = price * (100 - pool.delta) / 100;
            } else {
                price = price - pool.delta;
            };
            i = i + 1;
        };
        let item_id = object::id(&item);
        pay::split_and_transfer(&mut pool.funds, price, tx_context::sender(ctx), ctx);
        ofield::add(&mut pool.id, item_id, item);

        market_event::item_list_event(object::id(pool), item_id, tx_context::sender(ctx), price);
    }

    public fun buy<Item: store+key>(
        market: &mut Marketplace, 
        pool_id: ID,
        item_id: ID,
        paid: Coin<SUI>, 
        ctx: &mut TxContext
    ): Item {
        let pool = ofield::borrow_mut<ID, SellPool>(&mut market.id, pool_id);
        let price = pool.spot_price;
        let i = 0;
        while(i < pool.sold) {
            if(pool.curve_type){
                price = price * (100 + pool.delta) / 100;
            } else {
                price = price + pool.delta;
            };
            i = i + 1;
        };

        assert!(coin::value(&paid) >= price, ERR_AMOUNT_INCORRECT);

        let item = ofield::remove<ID, Item>(&mut pool.id, item_id);

        pay::split_and_transfer(&mut paid, price, pool.owner, ctx);

        market_event::item_puchased_event(object::id(pool), item_id, pool.owner, price);

        transfer::transfer(paid, tx_context::sender(ctx));
        item
    }

}
