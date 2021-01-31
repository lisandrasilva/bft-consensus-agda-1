{- Byzantine Fault Tolerant Consensus Verification in Agda, version 0.9.

   Copyright (c) 2020 Oracle and/or its affiliates.
   Licensed under the Universal Permissive License v 1.0 as shown at https://opensource.oracle.com/licenses/upl
-}
open import LibraBFT.Prelude
open import LibraBFT.Hash

open import LibraBFT.Abstract.Types

open import LibraBFT.Impl.NetworkMsg
open import LibraBFT.Impl.Consensus.Types

open import LibraBFT.Concrete.System.Parameters
open import LibraBFT.Concrete.Obligations

open import LibraBFT.Yasm.System     ConcSysParms
open import LibraBFT.Yasm.Properties ConcSysParms

-- In this module, we assume that the implementation meets its
-- obligations, and use this assumption to prove that the
-- implementatioon enjoys one of the per-epoch correctness conditions
-- proved in Abstract.Properties.  It can be extended to other
-- properties later.

module LibraBFT.Concrete.Properties (impl-correct : ImplObligations) where
  open ImplObligations impl-correct

  -- For any reachable state,
  module _ {e}(st : SystemState e)(r : ReachableSystemState st)(eid : Fin e) where
   open import LibraBFT.Concrete.System sps-cor
   open PerState st r
   open PerEpoch eid

   -- For any valid epoch within said state
   module _ (valid-𝓔 : ValidEpoch 𝓔) where
    import LibraBFT.Abstract.Records 𝓔 Hash _≟Hash_ (ConcreteVoteEvidence 𝓔) as Abs
    open import LibraBFT.Abstract.RecordChain 𝓔 Hash _≟Hash_ (ConcreteVoteEvidence 𝓔)
    open import LibraBFT.Abstract.System 𝓔 Hash _≟Hash_ (ConcreteVoteEvidence 𝓔)
    open import LibraBFT.Abstract.Properties 𝓔 valid-𝓔 Hash _≟Hash_ (ConcreteVoteEvidence 𝓔)

    open import LibraBFT.Concrete.Intermediate 𝓔 Hash _≟Hash_ (ConcreteVoteEvidence 𝓔)
    import LibraBFT.Concrete.Obligations.VotesOnce   𝓔 valid-𝓔 Hash _≟Hash_ (ConcreteVoteEvidence 𝓔) as VO-obl
    import LibraBFT.Concrete.Obligations.LockedRound 𝓔 valid-𝓔 Hash _≟Hash_ (ConcreteVoteEvidence 𝓔) as LR-obl
    open import LibraBFT.Concrete.Properties.VotesOnce as VO
    open import LibraBFT.Concrete.Properties.LockedRound as LR

    --------------------------------------------------------------------------------------------
    -- * A /ValidSysState/ is one in which both peer obligations are obeyed by honest peers * --
    --------------------------------------------------------------------------------------------

    record ValidSysState {ℓ}(𝓢 : IntermediateSystemState ℓ) : Set (ℓ+1 ℓ0 ℓ⊔ ℓ) where
      field
        vss-votes-once   : VO-obl.Type 𝓢
        vss-locked-round : LR-obl.Type 𝓢
    open ValidSysState public


    -- TODO-2 : This should be provided as a module parameter here, and the
    -- proofs provided to instantiate it should be refactored into LibraBFT.Impl.
    -- However, see the TODO-3 in LibraBFT.Concrete.Intermediate, which suggests
    -- that those proofs may change, perhaps some parts of them will remain in
    -- Concrete and others should be in Impl, depending on how that TODO-3 is
    -- addressed.  There is not much point in doing said refactoring until we
    -- make progress on that question.

    validState : ValidSysState IntSystemState
    validState = record
      { vss-votes-once   = VO.Proof.voo sps-cor vo₁ vo₂ st r eid valid-𝓔
      ; vss-locked-round = LR.Proof.lrr sps-cor lr₁ st r eid valid-𝓔
      }

    open IntermediateSystemState IntSystemState

    open All-InSys-props InSys
    open WithAssumptions InSys

    -- We can now invoke the various abstract correctness properties, using
    -- 
    ConcCommitsDoNotConflict :
       ∀{q q'}
       → {rc  : RecordChain (Abs.Q q)}  → All-InSys rc
       → {rc' : RecordChain (Abs.Q q')} → All-InSys rc'
       → {b b' : Abs.Block}
       → CommitRule rc  b
       → CommitRule rc' b'
       → NonInjective-≡ Abs.bId ⊎ ((Abs.B b) ∈RC rc' ⊎ (Abs.B b') ∈RC rc)
    ConcCommitsDoNotConflict = CommitsDoNotConflict
           (VO-obl.proof IntSystemState (vss-votes-once validState))
           (LR-obl.proof IntSystemState (vss-locked-round validState))

    module _ (∈QC⇒AllSent : Complete InSys) where

      ConcCommitsDoNotConflict' :
        ∀{q q'}{rc  : RecordChain (Abs.Q q)}{rc' : RecordChain (Abs.Q q')}{b b' : Abs.Block}
        → InSys (Abs.Q q) → InSys (Abs.Q q')
        → CommitRule rc  b
        → CommitRule rc' b'
        → NonInjective-≡ Abs.bId ⊎ ((Abs.B b) ∈RC rc' ⊎ (Abs.B b') ∈RC rc)
      ConcCommitsDoNotConflict' = CommitsDoNotConflict'
           (VO-obl.proof IntSystemState (vss-votes-once validState))
           (LR-obl.proof IntSystemState (vss-locked-round validState))
           ∈QC⇒AllSent

      ConcCommitsDoNotConflict''
        : ∀{o o' q q'}
        → {rcf  : RecordChainFrom o  (Abs.Q q)}
        → {rcf' : RecordChainFrom o' (Abs.Q q')}
        → {b b' : Abs.Block}
        → InSys (Abs.Q q)
        → InSys (Abs.Q q')
        → CommitRuleFrom rcf  b
        → CommitRuleFrom rcf' b'
        → NonInjective-≡ Abs.bId ⊎ Σ (RecordChain (Abs.Q q')) ((Abs.B b)  ∈RC_)
                                 ⊎ Σ (RecordChain (Abs.Q q))  ((Abs.B b') ∈RC_)
      ConcCommitsDoNotConflict'' = CommitsDoNotConflict''
           (VO-obl.proof IntSystemState (vss-votes-once validState))
           (LR-obl.proof IntSystemState (vss-locked-round validState))
           ∈QC⇒AllSent

