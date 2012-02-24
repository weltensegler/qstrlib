module DecisionProcedure where

-- standard modules
import qualified Data.Set as Set

-- local modules
import Basics
import qualified Interface.Sparq as S
import qualified Interface.Triangle as T
import DecisionProcedure.FlipFlop.OrientedMatroid

class HasDecisionProcedure a where
    proceduresForAtomicNets :: a ->
        [ ( String
          , Network [String] (Set.Set a) -> Maybe Bool )
        ]

    proceduresForNonAtomicNets :: a ->
        [ ( String
          , Network [String] (Set.Set a) -> Maybe Bool )
        ]


algebraicClosure str =
    ( "AC", (\(x,_,_) -> x) . S.algebraicClosure str )

ternaryAlgebraicClosure str =
    ( "TAC", (\(x,_,_) -> x) . S.ternaryAlgebraicClosure str )

algebraicReasoning str =
    ( "AR", S.algebraicReasoning str )

triangleConsistency =
    ( "TC", T.checkConsistency)

chirotopeSloppy =
    ( "OM s", isAcyclicChirotopeFlipFlop True)

biquadraticFinalPolynomialsSloppy =
    ( "BFP s", isAcyclicChirotopeWithoutBPFlipFlop True)

chirotope =
    ( "OM e", isAcyclicChirotopeFlipFlop False)

biquadraticFinalPolynomials =
    ( "BFP e", isAcyclicChirotopeWithoutBPFlipFlop False)
