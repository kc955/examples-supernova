// submited news will be checked to canisters >> verified/not, add up all the point of the verifier, recommendation will be based on most credible sources/like
// news removal protocol
import Trie "mo:base/Trie";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Option "mo:base/Option";
import Iter "mo:base/Iter";
import Nat "mo:base/Nat";
import Result "mo:base/Result";
import Error "mo:base/Error";
import ICRaw "mo:base/ExperimentalInternetComputer";
import List "mo:base/List";
import Time "mo:base/Time";
import Stack "mo:base/Stack";
import Types "./Types";
import RBTree "mo:base/RBTree";
import Map "mo:base/HashMap";
import Debug "mo:base/Debug";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";



actor {
    private var notesByUser = Map.HashMap<Text, Buffer.Buffer<Types.Writing>>(400, Text.equal, Text.hash);  
    private var viewsById = Map.HashMap<Nat, Trie.Trie<Nat, Types.Writing>>(400, Nat.equal, Int.hash);
    private var balanceByUser = Map.HashMap<Text, Nat>(400, Text.equal, Text.hash); 
    private var grantToOrg = Map.HashMap<Text, Nat>(10, Text.equal, Text.hash);
    var organizations : Trie.Trie<Text, DAO> = Trie.empty();

    var reading_fee = 1;
    stable var writing_id : Nat = 0;
    private type PrincipalName = Text;

    private var weekly_news = RBTree.RBTree<Nat, Types.Writing_identifier>(Nat.compare);
    private var hall_of_fame : Stack.Stack<(Principal,Nat)> = Stack.Stack();


    func organization_get(name : Text) : ?DAO = Trie.get(organizations, Types.organization_key(name), Text.equal);
    public shared({caller}) func organization_put(name : Text, desc : Text) {
        let organization : DAO = DAO(caller, name, desc);
        organizations := Trie.put(organizations, Types.organization_key(name), Text.equal, organization).0;
        balanceByUser.put(name, 0)
    };

    public func get_writing_id() : async Nat {
        writing_id+= 1;
        return writing_id;
    };

    //check the news or etc
    public shared({caller}) func upload_writing(index : Nat) : async Types.Result<(), Text> {
        var score : Nat = 0;
        let writings : [Types.Writing] = await get_notes();
        let file = writings.get(index);
        let array = file.verifier;
        for (org in array.vals()) {
            let group = organization_get(org);
            switch(group) {
                case null {score += 0};
                case (?group) {score += group.size}
                }
            };
        switch(?score) {
            case(null) {#err "Failed verification"};
            case(?Nat) {
                let identifier : Types.Writing_identifier = {
                    id_num = index; 
                    writer = caller; 
                };
                weekly_news.put(score, identifier);
                #ok
                    }
            }
    };


    // transfer token
    public shared ({ caller }) func transfer(target : Text, amount : Nat) : async Types.Result<(), Text> {
        let from = Principal.toText(caller);
        var balanceto : Nat = 0;
        var balancefrom : Nat = 0;
        switch (balanceByUser.get(from)){
            case null { #err "user does not exist"};
            case (?balance) {
                if (balance > amount){
                    let balanceto = Option.get(balanceByUser.get(target),0) + amount;
                    let balancefrom = balance - amount;
                }
                else {return #err "insufficient balance"};
                balanceByUser.put(target, balanceto);
                balanceByUser.put(from, balancefrom);
                #ok
            }
        }
    };

    public shared ({caller}) func open_news(writer : Principal, index : Nat) : async Types.Writing {
        let principalName = Principal.toText(writer);
        let userNotes : Buffer.Buffer<Types.Writing> = Option.get(notesByUser.get(principalName), Buffer.Buffer<Types.Writing>(0));
        let writing : Types.Writing = userNotes.get(index); 

        assert (writing.state == #free);
        let to = Principal.toText(writer);
        assert Result.isOk(await transfer(to, reading_fee));
        assert Result.isOk(await transfer("owner_principal", reading_fee/20));

        return writing;
        };


    

    /// organization
    ////////////////
    ////////////////
    class DAO(founder : Principal, name : Text, description : Text) = Self {
        public var id = name;
        public var desc = description;
        public var size : Nat = 1;    
        public var vote_reward : Nat = 1;
        public var fees : Trie.Trie<Text, Nat> = Trie.empty();
        public var thresholds = Types.threshold_fromArray(["join request", "verify news"]);
        public var comments = Map.HashMap<Nat, Buffer.Buffer<Types.Comment>>(10, Nat.equal, Int.hash);
        public var accounts : Trie.Trie<Principal, Nat> = Trie.empty();

        public var proposals : Trie.Trie<Nat, Types.Proposal> = Trie.empty();
        public var total_token : Nat = 0;
        public var questions : List.List<Types.Question> = List.nil();

        public func account_get(id : Principal) : ?Nat = Trie.get(accounts, Types.account_key(id), Principal.equal);
        public func account_put(id : Principal, tokens : Nat) {
        accounts := Trie.put(accounts, Types.account_key(id), Principal.equal, tokens).0;
        };
        account_put(founder, 1);
        
        public func proposal_get(id : Nat) : ?Types.Proposal = Trie.get(proposals, Types.proposal_key(id), Nat.equal);
        public func proposal_put(id : Nat, proposal : Types.Proposal) {
            proposals := Trie.put(proposals, Types.proposal_key(id), Nat.equal, proposal).0;
        }; 
        public func fees_get(inst :Text) : ?Nat =  Trie.get(fees, Types.fees_key(inst), Text.equal);
        public func fees_put(inst : Text, value :Nat) {
            fees := Trie.put(fees, Types.fees_key(inst), Text.equal, value).0;
        };
        public func threshold_get(inst :Text) : ?Nat=  Trie.get(thresholds, Types.threshold_key(inst), Text.equal);
        public func threshold_put(inst : Text, value : Nat) {
            thresholds := Trie.put(thresholds, Types.threshold_key(inst), Text.equal, value).0;
            };

        /// Reward for voting
        public func reward(amount : Nat, caller : Principal) {
            switch (account_get(caller)) {
                case null {};
                case (?balance) {
                    let to_amount = balance + vote_reward;
                    account_put(caller, to_amount);
                    total_token += vote_reward;
                };
            };
        };

    };

        /// Submit a proposalto and organization
    public shared({caller}) func submit_proposal(title : Text, desc: Text, tag : Text, income : Nat, org : Text, order : Nat) : async Types.Result<Nat, Text> {
        let rando : Principal = caller;
        let empty_DAO : DAO = DAO(rando, "", "");
        let organization = Option.get(organization_get(org), empty_DAO);
        let proposal_id = Types.proposal_key(writing_id);
        

        let proposal : Types.Proposal = {
            id = writing_id;
            ord = order;
            title = title;
            tag = tag;
            votes_no = 0;
            votes_yes = 0;
            voters = List.nil();
            state = #open;
            proposer = caller;
            payload = desc;
            threshold = organization.threshold_get(tag);
            comments = Buffer.Buffer<Types.Comment>(1);
        };
        organization.proposal_put(writing_id, proposal);
        writing_id += 1;
        #ok(writing_id)
    };

    public shared ({caller}) func submit_question(content : Text, title : Text, org : Text){
        let rando : Principal = caller;
        let empty_DAO : DAO = DAO(rando, "", "");
        let organization = Option.get(organization_get(org), empty_DAO);
        let principalName = Principal.toText(caller);
        let question : Types.Question = {
            title;
            content; 
            proposer = caller;
        };
        let writing = List.make(question); 
        organization.questions := List.append(organization.questions, writing);
    };

    /// Return the list of all proposals
    public query({caller}) func list_proposals(org : Text) : async [Types.Proposal] {
        let rando : Principal = caller;
        let empty_DAO : DAO = DAO(rando, "", "");
        let organization = Option.get(organization_get(org), empty_DAO);
        Iter.toArray(Iter.map(Trie.iter(organization.proposals), func (kv : (Nat, Types.Proposal)) : Types.Proposal = kv.1))
    };

    // Vote on an open proposal
    public shared({caller}) func vote(proposal_id : Nat, vote : Types.Vote, org : Text) : async Types.Result<Types.ProposalState, Text> {
        let rando : Principal = caller;
        let empty_DAO : DAO = DAO(rando, "", "");
        let organization = Option.get(organization_get(org), empty_DAO);
        switch (organization.proposal_get(proposal_id)) {
        case null { #err("No proposal with ID " # debug_show(proposal_id) # " exists") };
        case (?proposal) {
                var count = 1;
                var state = proposal.state;
                if (state != #open) {
                    return #err("Proposal " # debug_show(proposal_id) # " is not open for voting");
                };
                switch (organization.account_get(caller)) {
                case null { return #err("Caller is not a member") };
                case (?amount_e8s) {
                        if (List.some(proposal.voters, func (e : Principal) : Bool = e == caller)) {
                            return #err("Already voted");
                        };
                        var votes_yes = proposal.votes_yes;
                        var votes_no = proposal.votes_no;
                        // check if owner
                        switch (vote) {
                            case (#yes) { votes_yes += count };
                            case (#no) { votes_no += count };
                            //reward for voting
                        };
                        organization.reward(organization.vote_reward, caller);
                        let voters = List.push(caller, proposal.voters);
                            /// deal with result
                        if (votes_no >= Option.get(proposal.threshold,0)) {
                            state := #rejected;
                        };
                        if (votes_yes >= Option.get(proposal.threshold,0)) {
                            state := #accepted;
                            if (Text.equal(proposal.tag, "verify news")){
                                let writer = Option.get(notesByUser.get(Principal.toText(proposal.proposer)), Buffer.Buffer<Types.Writing>(1));
                                let writing : Types.Writing = writer.get(proposal.ord);
                                let updated_writing : Types.Writing = {
                                    id = writing.id; 
                                    title = writing.title;
                                    content = writing.content; 
                                    verifier = Array.append(writing.verifier, [org]);
                                    state = writing.state;
                                    likes = writing.likes;
                                    views = 0;
                                };
                                writer.put(proposal.ord, updated_writing);
                            };
                            if (Text.equal(proposal.tag, "join request")){
                                organization.account_put(proposal.proposer, 1)
                            } 
                            
                        };

                        let updated_proposal = {
                            id = proposal.id;
                            ord = proposal.ord;
                            votes_yes = votes_yes;   
                            title = proposal.title;                           
                            votes_no = votes_no;
                            voters = proposal.voters;
                            state = state;
                            tag = proposal.tag;
                            threshold = proposal.threshold;
                            proposer = proposal.proposer;
                            payload = proposal.payload;
                        };
                        organization.proposal_put(proposal_id, updated_proposal);
                    };
                };
                #ok(state)
            };
        };
    };
    // add comment to requests
    public shared ({caller}) func can_comment(proposal_id : Nat, org : Text) : async Types.Result<(), Text>{
        let rando : Principal = caller;
        let empty_DAO : DAO = DAO(rando, "", "");
        let organization = Option.get(organization_get(org), empty_DAO);
        switch(organization.proposal_get(proposal_id)) {
            case null {#err "no"};
            case (?proposal) {
                switch(organization.account_get(caller)){
                    case(null) {
                        if(Principal.equal(caller, proposal.proposer)) return #ok;
                        #err "not qualified";
                    };
                    case(?Tokens) {
                        return #ok
                    }
                }
            }
        }
    };



    //list all the feeds
    public query({caller}) func list_comments(proposal_id : Nat, org : Text): async [Types.Comment] {
        let rando : Principal = caller;
        let empty_DAO : DAO = DAO(rando, "", "");
        let organization = Option.get(organization_get(org), empty_DAO);
        let prop = organization.comments.get(proposal_id);
        switch (prop) {
            case null {return []};
            case (?prop) {
                return prop.toArray();
            }
        }
    };



    /// users

    
    //check if account exist
   private func is_user_registered(principal: Principal): Bool {
        Option.isSome(notesByUser.get(Principal.toText(principal)));
    };
    
    // return identity 
    public shared({ caller }) func whoami(): async Text {
        return Principal.toText(caller);
    };
    
    // add writings
    public shared({ caller }) func add_note(title : Text, writing : Text): async () {
        assert not Principal.isAnonymous(caller);
        assert is_user_registered(caller);

        Debug.print("Adding note...");

        let principalName = Principal.toText(caller);
        let newNote : Types.Writing = {
            id = writing_id; 
            title;
            content = writing; 
            verifier = []; 
            state = #for_self; 
            views = 0; 
            likes = 0;
            };
        writing_id += 1;
        let userNotes : Buffer.Buffer<Types.Writing> = Option.get(notesByUser.get(principalName), Buffer.Buffer<Types.Writing>(1));
        userNotes.add(newNote);

        notesByUser.put(principalName, userNotes);
        writing_id += 1;
    };

    //get writings to be uploaded to news feed
    public shared({ caller }) func get_notes(): async [Types.Writing] {
        assert not Principal.isAnonymous(caller);
        assert is_user_registered(caller);

        let principalName = Principal.toText(caller);
        let userNotes = Option.get(notesByUser.get(principalName), Buffer.Buffer<Types.Writing>(1));
        return userNotes.toArray();
    };

    public func get_news(): async[Types.Writing_identifier] {
        let list = RBTree.iter(weekly_news.share(), #bwd);
        var result : List.List<Types.Writing_identifier> = List.nil();
        for ((key,writing) in list) {
            let new = List.make(writing);
            result := List.append(result, new);
        };
        return List.toArray(result);
    }
}
