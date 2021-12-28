/**
 * Module     : zombieNFT.mo
 * Copyright  : 2021 Hellman Team
 * License    : Apache 2.0 with LLVM Exception
 * Maintainer : Hellman Team - Leven
 * Stability  : Experimental
 */

import WICP "../common/WICP";
import Types "../common/types";
import ZombieTypes "../common/zombieTypes";
import ZombieStorage "../storage/zombieStorage";
import Principal "mo:base/Principal";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Nat "mo:base/Nat";
import Bool "mo:base/Bool";
import HashMap "mo:base/HashMap";
import Option "mo:base/Option";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Time "mo:base/Time";
import Cycles "mo:base/ExperimentalCycles";
/**
 * Factory Canister to Create Canvas Canister
 */
shared(msg)  actor class ZombieNFT (owner_: Principal, feeTo_: Principal, wicpCanisterId_: Principal) = this {

    type WICPActor = WICP.WICPActor;
    type TokenIndex = Types.TokenIndex;
    type Balance = Types.Balance;
    type TransferResponse = Types.TransferResponse;
    type ListRequest = Types.ListRequest;
    type ListResponse = Types.ListResponse;
    type BuyResponse = Types.BuyResponse;
    type Listings = Types.Listings;
    type GetListingsRes = Types.GetListingsRes;
    type SoldListings = Types.SoldListings;
    type GetSoldListingsRes = Types.GetSoldListingsRes;
    type OpRecord = Types.OpRecord;
    type AncestorMintRecord = Types.AncestorMintRecord;
    type Operation = Types.Operation;
    type StorageActor = Types.ZombieStorageActor;
    type AirDropStruct = Types.AirDropStruct;
    type DisCountStruct = Types.DisCountStruct;
    type PreMint = Types.PreMint;
    type AirDropResponse = Types.AirDropResponse;
    type MintZombieResponse = Types.MintZombieResponse;
    type ZombieStoreCID = Types.CanvasIdentity;

    type Component = ZombieTypes.Component;
    type Token = ZombieTypes.Token;
    type TokenDetails = ZombieTypes.TokenDetails;
    type GetTokenResponse = ZombieTypes.GetTokenResponse;

    private stable var owner: Principal = owner_;
    private stable var feeTo: Principal = feeTo_;
    private stable var WICPCanisterActor: WICPActor = actor(Principal.toText(wicpCanisterId_));

    private stable var cyclesCreateCanvas: Nat = Types.CREATECANVAS_CYCLES;
    private stable var supply : Balance  = 5000;
    private stable var preMintAccount : Balance  = 0;
    private stable var preMintLimit : Balance  = 1000;
    private stable var marketFeeRatio : Nat  = 2;
    private stable var mintPrice : Balance  = 200_000_000;
    private stable var nftStoreCID : [Principal] = [];
    private stable var openTime: Time.Time = 1_639_447_200_000_000_000;
    private stable var storageCanister : ?StorageActor = null;

    private stable var componentsEntries : [(Nat, Component)] = [];
    private var components = HashMap.HashMap<TokenIndex, Component>(1, Types.TokenIndex.equal, Types.TokenIndex.hash); 

    private stable var tokensEntries : [(Nat, Token)] = [];
    private var tokens = HashMap.HashMap<TokenIndex, Token>(1, Types.TokenIndex.equal, Types.TokenIndex.hash);

    private stable var airDropEntries : [(Principal, Nat)] = [];
    private var airDrop = HashMap.HashMap<Principal, Nat>(1, Principal.equal, Principal.hash);

    private stable var disCountEntries : [(Principal, Nat)] = [];
    private var disCount = HashMap.HashMap<Principal, Nat>(1, Principal.equal, Principal.hash);

    private stable var listingsEntries : [(TokenIndex, Listings)] = [];
    private var listings = HashMap.HashMap<TokenIndex, Listings>(1, Types.TokenIndex.equal, Types.TokenIndex.hash);

    private stable var soldListingsEntries : [(TokenIndex, SoldListings)] = [];
    private var soldListings = HashMap.HashMap<TokenIndex, SoldListings>(1, Types.TokenIndex.equal, Types.TokenIndex.hash);

    // Mapping from owner to number of owned token
    private stable var balancesEntries : [(Principal, Nat)] = [];
    private var balances = HashMap.HashMap<Principal, Nat>(1, Principal.equal, Principal.hash);

    // Mapping from NFT canister ID to owner
    private stable var ownersEntries : [(TokenIndex, Principal)] = [];
    private var owners = HashMap.HashMap<TokenIndex, Principal>(1, Types.TokenIndex.equal, Types.TokenIndex.hash); 

    // Mapping from NFT canister ID to approved address
    private stable var availableEntries : [(TokenIndex, Bool)] = [];
    private var availableMint = HashMap.HashMap<TokenIndex, Bool>(1, Types.TokenIndex.equal, Types.TokenIndex.hash); 

    private var nftApprovals = HashMap.HashMap<TokenIndex, Principal>(1, Types.TokenIndex.equal, Types.TokenIndex.hash);
    // Mapping from owner to operator approvals
    private var operatorApprovals = HashMap.HashMap<Principal, HashMap.HashMap<Principal, Bool>>(1, Principal.equal, Principal.hash);
    private stable var dataUser : Principal = Principal.fromText("umgol-annoi-q7dqt-qbsw6-a2pww-eitzs-6vi5t-efaz6-xquey-5jmut-sqe");

    system func preupgrade() {
        componentsEntries := Iter.toArray(components.entries());
        tokensEntries := Iter.toArray(tokens.entries());

        listingsEntries := Iter.toArray(listings.entries());
        soldListingsEntries := Iter.toArray(soldListings.entries());
        balancesEntries := Iter.toArray(balances.entries());
        ownersEntries := Iter.toArray(owners.entries());
        availableEntries := Iter.toArray(availableMint.entries());
        airDropEntries := Iter.toArray(airDrop.entries());
        disCountEntries := Iter.toArray(disCount.entries());
    };

    system func postupgrade() {
        airDrop := HashMap.fromIter<Principal, Nat>(airDropEntries.vals(), 1, Principal.equal, Principal.hash);
        disCount := HashMap.fromIter<Principal, Nat>(disCountEntries.vals(), 1, Principal.equal, Principal.hash);
        balances := HashMap.fromIter<Principal, Nat>(balancesEntries.vals(), 1, Principal.equal, Principal.hash);
        owners := HashMap.fromIter<TokenIndex, Principal>(ownersEntries.vals(), 1, Types.TokenIndex.equal, Types.TokenIndex.hash);
        availableMint := HashMap.fromIter<TokenIndex, Bool>(availableEntries.vals(), 1, Types.TokenIndex.equal, Types.TokenIndex.hash);
        listings := HashMap.fromIter<TokenIndex, Listings>(listingsEntries.vals(), 1, Types.TokenIndex.equal, Types.TokenIndex.hash);
        soldListings := HashMap.fromIter<TokenIndex, SoldListings>(soldListingsEntries.vals(), 1, Types.TokenIndex.equal, Types.TokenIndex.hash);
        tokens := HashMap.fromIter<TokenIndex, Token>(tokensEntries.vals(), 1, Types.TokenIndex.equal, Types.TokenIndex.hash);
        components := HashMap.fromIter<TokenIndex, Component>(componentsEntries.vals(), 1, Types.TokenIndex.equal, Types.TokenIndex.hash);

        tokensEntries := [];
        componentsEntries := [];
        airDropEntries := [];
        disCountEntries := [];
        listingsEntries := [];
        soldListingsEntries := [];
        balancesEntries := [];
        ownersEntries := [];
        availableEntries := [];
    };

    public shared(msg) func setDataUser(user: Principal) : async Bool {
        assert(msg.caller == owner);
        dataUser := user;
        return true;
    };

    public shared(msg) func uploadTokens(tokenInfo: [Token]): async Bool {
        assert(_checkUsr(msg.caller));
        for (value in tokenInfo.vals()) {
            tokens.put(value.id, value);
        };
        true
    };

    public shared(msg) func getAllTokens(): async [(TokenIndex, Token)] {
        assert(_checkUsr(msg.caller));
        Iter.toArray(tokens.entries())
    };

    public shared(msg) func uploadComponents(components_data: [Component]): async Bool {
        assert(_checkUsr(msg.caller));
        for (data in components_data.vals()) {
            components.put(data.id, data);
        };
        true
    };

    public shared(msg) func getComponentsSize(): async Nat {
        components.size()
    };

    public query func getTokenById(tokenId:Nat): async GetTokenResponse{
        let token = switch(tokens.get(tokenId)){
            case (?t){t};
            case _ {return #err(#NotFoundIndex);};
        };
        let tmpBackground = switch(components.get(token.background)){
            case (?b) {b.attribute};
            case _ {return #err(#NotFoundIndex);};
        };
        let tmpLeg = switch(components.get(token.leg)){
            case (?l) {l.attribute};
            case _ {return #err(#NotFoundIndex);};
        };
        let tmpArm = switch(components.get(token.arm)){
            case (?a) {a.attribute};
            case _ {return #err(#NotFoundIndex);};
        };
        let tmpHead = switch(components.get(token.head)){
            case (?h) {h.attribute};
            case _ {return #err(#NotFoundIndex);};
        };
        let tmpHat = switch(components.get(token.hat)){
            case (?hat) {hat.attribute};
            case _ {return #err(#NotFoundIndex);};
        };
        let score = tmpBackground.rarityScore + tmpLeg.rarityScore + tmpArm.rarityScore
                        + tmpHead.rarityScore + tmpHat.rarityScore;

        let tokenDetail : TokenDetails = {
                id = token.id;
                background = tmpBackground;
                leg = tmpLeg;
                arm = tmpArm;
                head = tmpHead;
                hat = tmpHat;
                rarityScore = score;
        };
        #ok(tokenDetail)
    };

    private func _getRarityAndCE(tokenId:Nat) : (Float, Nat) {
        let token = switch(tokens.get(tokenId)){
            case (?t){t};
            case _ {return (0,0);};
        };
        let tmpBackground = switch(components.get(token.background)){
            case (?b) {b.attribute};
            case _ {return (0,0);};
        };
        let tmpLeg = switch(components.get(token.leg)){
            case (?l) {l.attribute};
            case _ {return (0,0);};
        };
        let tmpArm = switch(components.get(token.arm)){
            case (?a) {a.attribute};
            case _ {return (0,0);};
        };
        let tmpHead = switch(components.get(token.head)){
            case (?h) {h.attribute};
            case _ {return (0,0);};
        };
        let tmpHat = switch(components.get(token.hat)){
            case (?hat) {hat.attribute};
            case _ {return (0,0);};
        };
        let score = tmpBackground.rarityScore + tmpLeg.rarityScore + tmpArm.rarityScore
                        + tmpHead.rarityScore + tmpHat.rarityScore;
        let ce = tmpBackground.attack + tmpLeg.attack + tmpArm.attack
                        + tmpHead.attack + tmpHat.attack + tmpBackground.defense + tmpLeg.defense + tmpArm.defense
                        + tmpHead.defense + tmpHat.defense + tmpBackground.agile + tmpLeg.agile + tmpArm.agile
                        + tmpHead.agile + tmpHat.agile;
        (score, ce)
    };

    public shared(msg) func setStorageCanisterId(storage: ?Principal) : async Bool {
        assert(msg.caller == owner);
        switch(storage){
            case (?s) {storageCanister := ?actor(Principal.toText(s));};
            case _ {storageCanister := null;};
        };
        return true;
    };

    public query func getStorageCanisterId() : async ?Principal {
        switch(storageCanister){
            case(?s){?Principal.fromActor(s)};
            case _ {null};
        }
    };

    public shared(msg) func newStorageCanister(owner: Principal) : async Bool {
        assert(msg.caller == owner and storageCanister == null);
        Cycles.add(cyclesCreateCanvas);
        let storage = await ZombieStorage.ZombieStorage(owner);
        storageCanister := ?storage;
        return true;
    };

    public shared(msg) func setNftCanister(storeCIDArr: [Principal]) : async Bool {
        assert(msg.caller == owner_);
        nftStoreCID := storeCIDArr;
        return true;
    };

    public shared(msg) func getAllNftCanister() : async [Principal] {
        assert(msg.caller == owner_);
        nftStoreCID
    };

    private func randomNft() : async Nat {
        let now = Time.now();
        let arr = Iter.toArray(availableMint.entries());
        var lotteryIndex = Int.abs(now) % arr.size();
        while(Option.isSome(owners.get(lotteryIndex))){
            lotteryIndex := (lotteryIndex + 1) % arr.size();
        };
        return arr[lotteryIndex].0;
    };

    public shared(msg) func cliamAirdrop() : async AirDropResponse {
        let remain = switch(airDrop.get(msg.caller)){
            case (?a){a};
            case _ {return #err(#NotInAirDropListOrAlreadyCliam);};
        };
        if(remain == 0){
            return #err(#AlreadyCliam);
        };
        if(availableMint.size() == 0){
            return #err(#AlreadyCliam);
        };
        let tokenIndex = await randomNft();
        owners.put(tokenIndex, msg.caller);
        balances.put( msg.caller, _balanceOf(msg.caller) + 1 );
        availableMint.delete(tokenIndex);
        switch(storageCanister){
            case(?s){ignore s.addRecord(tokenIndex, #Mint, null, ?msg.caller, null, Time.now());};
            case _ {};
        };
        if(remain == 1){
            airDrop.delete(msg.caller);
        }else if (remain > 1){
            airDrop.put(msg.caller,remain - 1);
        };
        let zombieInfo: ZombieStoreCID = { 
            index=tokenIndex; 
            canisterId=nftStoreCID[tokenIndex/1000];
        };
        return #ok(zombieInfo);
    };

    private func randomNfts(mintAmount: Nat) : async [Nat] {
        var ret: [Nat] = [];

        let now = Time.now();
        let arr = Iter.toArray(availableMint.entries());
        if(arr.size() < mintAmount){
            return ret;
        };
        for(i in Iter.range(0, mintAmount-1)){
            var lotteryIndex = ( Int.abs(now)/(i+1)) % arr.size();
            while(Option.isSome(owners.get(lotteryIndex)) or 
                    Option.isSome(Array.find<Nat>(ret, func(v) {v == lotteryIndex}))
            ){
                lotteryIndex := (lotteryIndex + 1) % arr.size();
            };
            ret := Array.append(ret, [arr[lotteryIndex].0]);
        };
        return ret;
    };

    public shared(msg) func proAvailableMint() : async Bool {
        assert(msg.caller == owner);
        for(i in Iter.range(0,4999)){
            if(Option.isNull(owners.get(i))){
                availableMint.put(i, true);
            };
        };
        return true;
    };

    public query func getAvailableMint() : async [(TokenIndex, Bool)] {
        Iter.toArray(availableMint.entries())
    };

    //create Multi-party Canvas Canister
    public shared(msg) func mintZombie(mintAmount: Nat) : async MintZombieResponse {
        assert(mintAmount > 0);
        let now: Time.Time = Time.now();
        if( now < openTime ) { return #err(#NotOpen); };
        if(preMintAccount >= preMintLimit){ return #err(#SoldOut); };
        if(preMintAccount + mintAmount > preMintLimit){ return #err(#NotEnoughToMint); };

        let dis = switch(disCount.get(msg.caller)){
            case (?d){d};
            case _ {100};
        };
        
        let tokenIndexArr = await randomNfts(mintAmount);
        if(tokenIndexArr.size() == 0){ return #err(#SoldOut); };

        let price = Nat.div(Nat.mul(mintPrice, dis), 100);
        let transferResult = await WICPCanisterActor.transferFrom(msg.caller, feeTo, price * tokenIndexArr.size());
        switch(transferResult){
            case(#ok(b)) {};
            case(#err(errText)){
                return #err(errText);
            };
        };

        var records: [AncestorMintRecord] = [];
        var zombieIdArr: [ZombieStoreCID] = [];

        for(v in tokenIndexArr.vals()){
            let rec: AncestorMintRecord = {
                index = v;
                record = {op = #Mint; from = null; to = ?msg.caller; price = null; timestamp = now;};
            };
            let zombieId: ZombieStoreCID = { 
                index=v; 
                canisterId=nftStoreCID[v/1000];
            };
            availableMint.delete(v);
            records := Array.append(records, [rec]);
            zombieIdArr := Array.append(zombieIdArr, [zombieId]);
            owners.put(v, msg.caller);
        };
        balances.put( msg.caller, _balanceOf(msg.caller) + tokenIndexArr.size() );
        preMintAccount += tokenIndexArr.size();
        switch(storageCanister){
            case(?s){ignore s.addRecords(records);};
            case _ {};
        };

        disCount.delete(msg.caller);
        return #ok(zombieIdArr);
    };

    public shared(msg) func uploadAirDropList(airDropList: [AirDropStruct]) : async Bool {
        assert(msg.caller == owner);
        for(value in airDropList.vals()){
            airDrop.put(value.user, value.remainTimes);
        };
        return true;
    };

    public shared(msg) func clearAirDrop() : async Bool {
        assert(msg.caller == owner);
        airDrop := HashMap.HashMap<Principal, Nat>(0, Principal.equal, Principal.hash);
        return true;
    };

    public shared(msg) func uploadDisCountList(disCountList: [DisCountStruct]) : async Bool {
        assert(msg.caller == owner);
        for(value in disCountList.vals()){
            disCount.put(value.user, value.disCount);
        };
        return true;
    };

    public shared(msg) func clearDisCount() : async Bool {
        assert(msg.caller == owner);
        disCount := HashMap.HashMap<Principal, Nat>(0, Principal.equal, Principal.hash);
        return true;
    };

    public shared(msg) func preMintZombie(preMintArr: [PreMint]) : async Bool {
        assert(msg.caller == owner);
        var records: [AncestorMintRecord] = [];
        for(v in preMintArr.vals()){
            let rec: AncestorMintRecord = {
                index = v.index;
                record = {op = #Mint; from = null; to = ?v.user; price = null; timestamp = Time.now();};
            };
            records := Array.append(records, [rec]);
            owners.put(v.index, v.user);
        };
        switch(storageCanister){
            case(?s){ignore s.addRecords(records);};
            case _ {};
        };
        return true;
    };

    public shared(msg) func preMintZombie2(preMintArr: [PreMint]) : async Bool {
        assert(msg.caller == owner);
        for(v in preMintArr.vals()){
            owners.put(v.index, v.user);
            balances.put( v.user, _balanceOf(v.user) + 1 );
        };
        return true;
    };

    public shared(msg) func setPreMintLimit(preLimit: Nat) : async Bool {
        assert(msg.caller == owner);
        preMintLimit := preLimit;
        return true;
    };

    public query func reaminCountofPreMint() : async Nat {
        preMintLimit - preMintAccount
    };

    public query func getPreMintLimit() : async Nat {
        preMintLimit
    };

    public shared(msg) func setOpenTime(newTime: Time.Time) : async Bool {
        assert(msg.caller == owner);
        openTime := newTime;
        return true;
    };

    public query func getOpenTime() : async Time.Time {
        openTime
    };

    public shared(msg) func setFavorite(tokenIndex: TokenIndex): async Bool {
        switch(storageCanister){
            case(?s){
                let info: ZombieStoreCID = { 
                    index=tokenIndex; 
                    canisterId=nftStoreCID[tokenIndex/1000];
                };
                ignore s.setFavorite(msg.caller, info);
            };
            case _ {};
        };
        return true;
    };

    public shared(msg) func cancelFavorite(tokenIndex: TokenIndex): async Bool {
        switch(storageCanister){
            case(?s){
                let info: ZombieStoreCID = { 
                    index=tokenIndex; 
                    canisterId=nftStoreCID[tokenIndex/1000];
                };
                ignore s.cancelFavorite(msg.caller, info);
            };
            case _ {};
        };
        return true;
    };

    //modify the PixelCanvas NFT to newOwner's map when oldOwner sell the NFT to another
    public shared(msg) func transferFrom(from: Principal, to: Principal, tokenIndex: TokenIndex): async TransferResponse {
        if(Option.isSome(listings.get(tokenIndex))){
            return #err(#ListOnMarketPlace);
        };
        if( not _isApprovedOrOwner(from, msg.caller, tokenIndex) ){
            return #err(#NotOwnerOrNotApprove);
        };
        if(from == to){
            return #err(#NotAllowTransferToSelf);
        };
        _transfer(from, to, tokenIndex);
        if(Option.isSome(listings.get(tokenIndex))){
            listings.delete(tokenIndex);
        };
        switch(storageCanister){
            case(?s){ignore s.addRecord(tokenIndex, #Transfer, ?from, ?to, null, Time.now());};
            case _ {};
        };
        return #ok(tokenIndex);
    };

    public shared(msg) func batchTransferFrom(from: Principal, tos: [Principal], tokenIndexs: [TokenIndex]): async TransferResponse {
        if(tokenIndexs.size() == 0 or tos.size() == 0
            or tokenIndexs.size() != tos.size()){
            return #err(#Other);
        };
        for(v in tokenIndexs.vals()){
            if(Option.isSome(listings.get(v))){
                return #err(#ListOnMarketPlace);
            };
            if( not _isApprovedOrOwner(from, msg.caller, v) ){
                return #err(#NotOwnerOrNotApprove);
            };
        };
        for(i in Iter.range(0, tokenIndexs.size() - 1)){
            _transfer(from, tos[i], tokenIndexs[i]);
        };
        return #ok(tokenIndexs[0]);
    };

    public shared(msg) func approve(approve: Principal, tokenIndex: TokenIndex): async Bool{
        let ow = switch(_ownerOf(tokenIndex)){
            case(?o){o};
            case _ {return false;};
        };
        if(ow != msg.caller){return false;};
        nftApprovals.put(tokenIndex, approve);
        return true;
    };

    public shared(msg) func setApprovalForAll(operatored: Principal, approved: Bool): async Bool{
        assert(msg.caller != operatored);
        switch(operatorApprovals.get(msg.caller)){
            case(?op){
                op.put(operatored, approved);
                operatorApprovals.put(msg.caller, op);
            };
            case _ {
                var temp = HashMap.HashMap<Principal, Bool>(1, Principal.equal, Principal.hash);
                temp.put(operatored, approved);
                operatorApprovals.put(msg.caller, temp);
            };
        };
        return true;
    };

    public shared(msg) func list(listReq: ListRequest): async ListResponse {
        if(Option.isSome(listings.get(listReq.tokenIndex))){
            return #err(#AlreadyList);
        };
        if(not _checkOwner(listReq.tokenIndex, msg.caller)){
            return #err(#NotOwner);
        };
        let timeStamp = Time.now();
        var order:Listings = {
            tokenIndex = listReq.tokenIndex; 
            seller = msg.caller; 
            price = listReq.price;
            time = timeStamp;
        };
        listings.put(listReq.tokenIndex, order);
        switch(storageCanister){
            case(?s){ignore s.addRecord(listReq.tokenIndex, #List, ?msg.caller, null, ?listReq.price, timeStamp);};
            case _ {};
        };
        return #ok(listReq.tokenIndex);
    };

    public shared(msg) func updateList(listReq: ListRequest): async ListResponse {
        let orderInfo = switch(listings.get(listReq.tokenIndex)){
            case (?o){o};
            case _ {return #err(#NotFoundIndex);};
        };
        if(listReq.price == orderInfo.price){
            return #err(#SamePrice);
        };
        if(not _checkOwner(listReq.tokenIndex, msg.caller)){
            return #err(#NotOwner);
        };
        let timeStamp = Time.now();
        var order:Listings = {
            tokenIndex = listReq.tokenIndex; 
            seller = msg.caller; 
            price = listReq.price;
            time = timeStamp;
        };
        listings.put(listReq.tokenIndex, order);
        switch(storageCanister){
            case(?s){ignore s.addRecord(listReq.tokenIndex, #UpdateList, ?msg.caller, null, ?listReq.price, timeStamp);};
            case _ {};
        };
        return #ok(listReq.tokenIndex);
    };

    public shared(msg) func cancelList(tokenIndex: TokenIndex): async ListResponse {
        let orderInfo = switch(listings.get(tokenIndex)){
            case (?o){o};
            case _ {return #err(#NotFoundIndex);};
        };
        
        if(not _checkOwner(tokenIndex, msg.caller)){
            return #err(#NotOwner);
        };
        var price: Nat = orderInfo.price;
        listings.delete(tokenIndex);
        switch(storageCanister){
            case(?s){ ignore s.addRecord(tokenIndex, #CancelList, ?msg.caller, null, ?price, Time.now());};
            case _ {};
        };
        return #ok(tokenIndex);
    };

    public shared(msg) func buyNow(tokenIndex: TokenIndex): async BuyResponse {
        let orderInfo = switch(listings.get(tokenIndex)){
            case (?l){l};
            case _ {return #err(#NotFoundIndex);};
        };
        if(msg.caller == orderInfo.seller){
            return #err(#NotAllowBuySelf);
        };
        
        if(not _checkOwner(tokenIndex, orderInfo.seller)){
            listings.delete(tokenIndex);
            return #err(#AlreadyTransferToOther);
        };

        var tos: [Principal] = [];
        var values: [Nat] = [];

        let value:Nat = Nat.div(Nat.mul(orderInfo.price, 100 - marketFeeRatio), 100);
        let marketFee:Nat = orderInfo.price - value;

        tos := Array.append(tos, [orderInfo.seller]);
        tos := Array.append(tos, [feeTo]);
        values := Array.append(values, [value]);
        values := Array.append(values, [marketFee]);

        let transferResult = await WICPCanisterActor.batchTransferFrom(msg.caller, tos, values);
        switch(transferResult){
            case(#ok(b)) {};
            case(#err(errText)){
                return #err(errText);
            };
        };
        var price: Nat = orderInfo.price;
        listings.delete(tokenIndex);
        _transfer(orderInfo.seller, msg.caller, orderInfo.tokenIndex);
        _addSoldListings(orderInfo);
        switch(storageCanister){
            case(?s){ ignore s.addBuyRecord(tokenIndex, ?orderInfo.seller, ?msg.caller, ?price, Time.now());};
            case _ {};
        };
        return #ok(tokenIndex);
    };

    public shared(msg) func setWICPCanisterId(wicpCanisterId: Principal) : async Bool {
        assert(msg.caller == owner);
        WICPCanisterActor := actor(Principal.toText(wicpCanisterId));
        return true;
    };

    public shared(msg) func setOwner(newOwner: Principal) : async Bool {
        assert(msg.caller == owner);
        owner := newOwner;
        return true;
    };

    public shared(msg) func setFeeTo(newFeeTo: Principal) : async Bool {
        assert(msg.caller == owner);
        feeTo := newFeeTo;
        return true;
    };

    public shared(msg) func setMarketFeeRatio(newRatio: Nat) : async Bool {
        assert(msg.caller == owner and marketFeeRatio < 10);
        marketFeeRatio := newRatio;
        return true;
    };

    public shared(msg) func setMintPrice(newPrice: Nat) : async Bool {
        assert(msg.caller == owner);
        mintPrice := newPrice;
        return true;
    };

    public shared(msg) func wallet_receive() : async Nat {
        let available = Cycles.available();
        let accepted = Cycles.accept(available);
        return accepted;
    };

    public query func getListings() : async [(ZombieStoreCID, GetListingsRes)] {

        var ret: [(ZombieStoreCID, GetListingsRes)] = [];
        for((k,v) in listings.entries()){
            let identity:ZombieStoreCID = {
                index = k;
                canisterId = nftStoreCID[k/1000];
            };
            let scoreAndCE = _getRarityAndCE(k);
            let res: GetListingsRes = {
                listings = v;
                rarityScore = scoreAndCE.0;
                CE = scoreAndCE.1;
            };
            ret := Array.append(ret, [(identity, res)]);
        };
        return ret;
    };

    public query func getSoldListings() : async [(ZombieStoreCID, GetSoldListingsRes)] {

        var ret: [(ZombieStoreCID, GetSoldListingsRes)] = [];
        for((k,v) in soldListings.entries()){
            let identity:ZombieStoreCID = {
                index = k;
                canisterId = nftStoreCID[k/1000];
            };
            let scoreAndCE = _getRarityAndCE(k);
            let res: GetSoldListingsRes = {
                listings = v;
                rarityScore = scoreAndCE.0;
                CE = scoreAndCE.1;
            };
            ret := Array.append(ret, [(identity, res)]);
        };
        return ret;
    };

    public query func isList(index: TokenIndex) : async ?Listings {
        listings.get(index)
    };

    public query func getApproved(tokenIndex: TokenIndex) : async ?Principal {
        nftApprovals.get(tokenIndex)
    };

    public query func getFeeTo() : async Principal {
        feeTo
    };

    public query func getMintPrice() : async Nat {
        mintPrice
    };

    public query func getMarketFeeRatio() : async Nat {
        marketFeeRatio
    };

    public query func isApprovedForAll(owner: Principal, operatored: Principal) : async Bool {
        _checkApprovedForAll(owner, operatored)
    };

    public query func ownerOf(tokenIndex: TokenIndex) : async ?Principal {
        _ownerOf(tokenIndex)
    };

    public query func balanceOf(user: Principal) : async Nat {
        _balanceOf(user)
    };

    public query func getCycles() : async Nat {
        return Cycles.balance();
    };

    public query func getWICPCanisterId() : async Principal {
        Principal.fromActor(WICPCanisterActor)
    };

    public query func getAllNFT(user: Principal) : async [(TokenIndex, Principal)] {
        var ret: [(TokenIndex, Principal)] = [];
        for((k,v) in owners.entries()){
            if(v == user){
                ret := Array.append(ret, [ (k, nftStoreCID[k/1000]) ] );
            };
        };
        Array.sort(ret, func (x : (TokenIndex, Principal), y : (TokenIndex, Principal)) : { #less; #equal; #greater } {
            if (x.0 < y.0) { #less }
            else if (x.0 == y.0) { #equal }
            else { #greater }
        })
    };

    public query func getAvaiableNFT(user: Principal) : async [(TokenIndex, Principal)] {
        var ret: [(TokenIndex, Principal)] = [];
        for((k,v) in owners.entries()){
            if(v == user and Option.isNull(listings.get(k))){
                ret := Array.append(ret, [ (k, nftStoreCID[k/1000]) ] );
            };
        };
        Array.sort(ret, func (x : (TokenIndex, Principal), y : (TokenIndex, Principal)) : { #less; #equal; #greater } {
            if (x.0 < y.0) { #less }
            else if (x.0 == y.0) { #equal }
            else { #greater }
        })
    };

    public shared query(msg) func getAllZombie() : async [(TokenIndex, Principal)] {
        assert(msg.caller == owner);
        Iter.toArray(owners.entries())
    };

    public query func getAllZombieHolder(user: Principal) : async [Principal] {
        var ret: [Principal] = [];
        for((k,v) in owners.entries()){
            if(_checkPrincipal(v)){
                ret := Array.append(ret, [v] );
            };
        };
        return ret;
    };

    public query func getAirDropRemain(user: Principal) : async Nat {
        switch(airDrop.get(user)){
            case (?n){n};
            case _ {0};
        }
    };

    public shared query(msg) func getAirDropLeft() : async [(Principal, Nat)] {
        assert(msg.caller == owner);
        Iter.toArray(airDrop.entries())
    };

    public shared query(msg) func getDisCountLeft() : async [(Principal, Nat)] {
        assert(msg.caller == owner);
        Iter.toArray(disCount.entries())
    };

    public query func getDisCountByUser(user: Principal) : async Nat {
        var dis:Nat = 100;
        switch(disCount.get(user)){
            case (?d){dis := d;};
            case _ {};
        };
        dis
    };

    private func _checkPrincipal(id: Principal) : Bool {
        Principal.toText(id).size() > 60
    };

    private func _checkUsr(usr: Principal) : Bool {
        usr == owner or usr == dataUser
    };

    private func _balanceOf(owner: Principal): Nat {
        switch(balances.get(owner)){
            case (?n){n};
            case _ {0};
        }
    };

    private func _transfer(from: Principal, to: Principal, tokenIndex: TokenIndex) {
        balances.put( from, _balanceOf(from) - 1 );
        balances.put( to, _balanceOf(to) + 1 );
        nftApprovals.delete(tokenIndex);
        owners.put(tokenIndex, to);
    };

    private func _addSoldListings( orderInfo :Listings) {
        switch(soldListings.get(orderInfo.tokenIndex)){
            case (?sold){
                let newDeal = {
                    lastPrice = orderInfo.price;
                    time = Time.now();
                    account = sold.account + 1;
                };
                soldListings.put(orderInfo.tokenIndex, newDeal);
            };
            case _ {
                let newDeal = {
                    lastPrice = orderInfo.price;
                    time = Time.now();
                    account = 1;
                };
                soldListings.put(orderInfo.tokenIndex, newDeal);
            };
        };
    };

    private func _ownerOf(tokenIndex: TokenIndex) : ?Principal {
        owners.get(tokenIndex)
    };

    private func _checkOwner(tokenIndex: TokenIndex, from: Principal) : Bool {
        switch(owners.get(tokenIndex)){
            case (?o){
                if(o == from){
                    true
                }else{
                    false
                }
            };
            case _ {false};
        }
    };

    private func _checkApprove(tokenIndex: TokenIndex, approved: Principal) : Bool {
        switch(nftApprovals.get(tokenIndex)){
            case (?o){
                if(o == approved){
                    true
                }else{
                    false
                }
            };
            case _ {false};
        }
    };

    private func _checkApprovedForAll(owner: Principal, operatored: Principal) : Bool {
        switch(operatorApprovals.get(owner)){
            case (?a){
                switch(a.get(operatored)){
                    case (?b){b};
                    case _ {false};
                }
            };
            case _ {false};
        }
    };

    private func _isApprovedOrOwner(from: Principal, spender: Principal, tokenIndex: TokenIndex) : Bool {
        _checkOwner(tokenIndex, from) and (_checkOwner(tokenIndex, spender) or 
        _checkApprove(tokenIndex, spender) or _checkApprovedForAll(from, spender))
    };
}