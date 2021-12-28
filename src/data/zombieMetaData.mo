import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Text "mo:base/Text";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Float "mo:base/Float";
import Bool "mo:base/Bool";
import Cycles "mo:base/ExperimentalCycles";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Iter "mo:base/Iter";
import Types "../common/zombieTypes";
import Hash "mo:base/Hash";

shared(msg) actor class ZombieMetaData(_owner: Principal, _offset: Nat) = this {
    type HttpRequest = Types.HttpRequest;
    type HttpResponse = Types.HttpResponse;
    type Result<T,E> = Result.Result<T,E>;
    type Image = Types.Image;

    private stable var owner : Principal = _owner;
    private stable var offset : Nat = _offset;
    private stable var imageDatas: [var Types.Image] = Array.init<Types.Image>(1000, Blob.fromArray([]));
    private stable var thumbnail: [var Types.Image] = Array.init<Types.Image>(1000, Blob.fromArray([]));
    
    private stable var dataUser : Principal = Principal.fromText("umgol-annoi-q7dqt-qbsw6-a2pww-eitzs-6vi5t-efaz6-xquey-5jmut-sqe");

    public shared(msg) func setDataUser(user: Principal) : async Bool {
        assert(msg.caller == owner);
        dataUser := user;
        return true;
    };

    public shared(msg) func uploadImage(token_id: Nat,tokenImage: [Nat8], imageType: Text): async Bool{
        assert(_checkUsr(msg.caller));
        let nftData = Blob.fromArray(tokenImage);
        if (imageType == "thumbnail") {
            thumbnail[token_id] := nftData;
        }else if (imageType == "original") {
            if (imageDatas[token_id] != Blob.fromArray([])) {
                let originData = Blob.toArray(imageDatas[token_id]);
                imageDatas[token_id] := Blob.fromArray(Array.append(originData,tokenImage));
            }else {
                imageDatas[token_id] := nftData;
            };
        }else {assert(false)};
        true
    };

    public shared(msg) func deleteImage(token_id: Nat): async Bool{
        assert(_checkUsr(msg.caller));
        imageDatas[token_id - offset] := Blob.fromArray([]);
        true
    };

    public query func http_request(request: HttpRequest) : async HttpResponse {
        
        let path = Iter.toArray(Text.tokens(request.url, #text("/")));
        if (path.size() != 2){
            assert(false);
        };

        var nftData :Image = Blob.fromArray([]);
        let tokenId = Types.textToNat(path[1]);
        if(tokenId < offset or _safeMinus(tokenId, offset) > 999){
            assert(false);
        };

        if (path[0] == "thumbnail") {
            nftData := thumbnail[tokenId - offset];
        }else if (path[0] == "token") {
            nftData := imageDatas[tokenId - offset];
        }else {assert(false)};

        return {
                body = nftData;
                headers = [("Content-Type", "image/png")];
                status_code = 200;
                streaming_strategy = null;
        };
    };

    public shared(msg) func wallet_receive() : async Nat {
        let available = Cycles.available();
        let accepted = Cycles.accept(available);
        return accepted;
    };

    public query func getCycles() : async Nat {
        return Cycles.balance();
    };

    private func _checkUsr(usr: Principal) : Bool {
        var ret = false;
        if(usr == owner or usr == dataUser){
            ret := true;
        };
        ret
    };

    private func _safeMinus(x: Nat, y: Nat) : Nat {
        if(x >= y){
            x-y
        }else{
            0
        }
    };

    system func preupgrade() {    
    };

    system func postupgrade() {
    };
 
}