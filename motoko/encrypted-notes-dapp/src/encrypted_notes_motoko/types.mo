import Text "mo:base/Text";
import Result "mo:base/Result";
import Trie "mo:base/Trie";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import List "mo:base/List";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Stack "mo:base/Stack";
import RBTree "mo:base/RBTree";
import Iter "mo:base/Iter";
import Order "mo:base/Order";
import Buffer "mo:base/Buffer";


module {
  public type Result<T, E> = Result.Result<T, E>;
  public type Account = { owner : Principal; tokens : Nat };
  public type Comment = {content : Text; proposer : Principal};
  public type Writing = {
    id : Nat; 
    title : Text;
    content : Text; 
    verifier : [Text];
    state : {#free; #for_self};
    likes : Nat;
    views : Nat;
    };
  public type Writing_identifier = {writer : Principal; id_num : Nat};
  public type Proposal = {
    id : Nat;
    ord : Nat;
    title : Text;
    tag: Text;
    votes_no : Nat;
    votes_yes : Nat;
    voters : List.List<Principal>;
    state : ProposalState;
    proposer : Principal;
    payload : Text;
    threshold : ?Nat;
  };

  public type Question = {
    title : Text;
    content : Text; 
    proposer : Principal;
  };
  public type ProposalState = {
      // A failure occurred while executing the proposal
      #failed : Text;
      // The proposal is open for voting
      #open;
      // Enough "no" votes have been cast to reject the proposal, and it will not be executed
      #rejected;
      // Enough "yes" votes have been cast to accept the proposal, and it will soon be executed
      #accepted;
  };
  public type Tokens = { amount_e8s : Nat };
  public type TransferArgs = { to : Principal; amount : Nat };
  public type UpdateSystemParamsPayload = {
    transfer_fee : ?Nat;
    proposal_vote_threshold : ?Nat;
    proposal_submission_deposit : ?Nat;
  };
  public type Vote = { #no; #yes };
  public type VoteArgs = { vote : Vote; proposal_id : Nat };

  public type SystemParams = {
    transfer_fee: Nat;

    // The amount of tokens needed to vote "yes" to accept, or "no" to reject, a proposal
    proposal_vote_threshold: Nat;

    // The amount of tokens that will be temporarily deducted from the account of
    // a user that submits a proposal. If the proposal is Accepted, this deposit is returned,
    // otherwise it is lost. This prevents users from submitting superfluous proposals.
    proposal_submission_deposit: Nat;
  };

  public func proposal_key(t: Nat) : Trie.Key<Nat> = { key = t; hash = Int.hash t };
  public func organization_key(t: Text) : Trie.Key<Text> = { key = t; hash = Text.hash(t)};
  public func fees_key(t: Text) : Trie.Key<Text> = { key = t; hash = Text.hash(t)};
  public func threshold_key(t: Text) : Trie.Key<Text> = { key = t; hash = Text.hash(t)};
  public func account_key(t: Principal) : Trie.Key<Principal> = { key = t; hash = Principal.hash(t)};

  public func accounts_fromArray(arr: [Account]) : Trie.Trie<Principal, Nat> {
      var s = Trie.empty<Principal, Nat>();
      for (account in arr.vals()) {
          s := Trie.put(s, account_key(account.owner), Principal.equal, account.tokens).0;
      };
      s
  };

  public func threshold_fromArray(arr: [Text]) : Trie.Trie<Text, Nat>  {
      var s = Trie.empty<Text, Nat>();
      for (tag in arr.vals()) {
          s := Trie.put(s, threshold_key(tag), Text.equal, 1).0;
      };
      s
  };

  public let oneToken = { amount_e8s = 10_000_000 };
  public let zeroToken = { amount_e8s = 0 };  

}
