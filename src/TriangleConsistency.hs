module TriangleConsistency where

import qualified Data.Set as Set
import qualified Data.List as List
import qualified Data.Map as Map
import System.Process
import Data.Maybe

type Variable = (Int, Int, Int)
type Constant = Int

data Rel = Rel
          {
            pa  :: Int
          , pb  :: Int
          , rel :: String
          , pc  :: Int
          }
          deriving (Eq, Ord)

data Term =
    Var      Variable  |
    SVar     String    |
    Constant Constant  |
    Addition Term Term |
    Negation Term
    deriving (Eq,Ord)

instance Show Term where
    show t = case t of
               Var  (v1, v2, v3) -> "v"++ show v1 ++ "_" ++ show v2 ++ "_" ++ show v3
               Constant c        -> show c
               Addition s t1     -> (show s) ++ " + " ++ (show t1)
               Negation n        -> "-" ++ show n
               SVar n            -> n

data Equation =
    Equal Term Term |
    Less  Term Term |
    LE    Term Term
    deriving (Eq,Ord)

instance Show Equation where
    show e =
        case e of
          Equal s t -> (show s) ++ " = " ++ (show t)
          Less  s t -> (show s) ++ " < " ++ (show t)
          LE    s t -> (show s) ++ " <= " ++ (show t)

subs :: [Rel] -> [Rel]
subs lst = filter (\x -> rel x == "S"
                      || rel x == "E"
                      || rel x == "Dou"
                      || rel x == "Tri") lst

createSubsMap :: [Rel] -> Map.Map Int Int
createSubsMap lst =
      foldl (\x y -> case rel y of
                       "S"   -> Map.insert (pc y) (pa y) x
                       "E"   -> Map.insert (pc y) (pb y) x
                       "Dou" -> Map.insert (pb y) (pa y) x
                       "Tri" -> Map.insert (pc y) (pa y)
                           $ Map.insert (pb y) (pa y) x
            ) Map.empty $ subs lst

cmpsMap :: (Ord k) => Map.Map k k -> Map.Map k k
cmpsMap mp =
    let
        cmps = map (\(x,y) ->
                      ((x,y), filter (\(z,_) -> z == y) $ Map.toList mp))
            $ Map.toList mp
    in
      if (and $ map (\(_,z) -> z == []) $ cmps) then
          mp
      else
          cmpsMap $ Map.fromList $ map (\((x,y),l) ->
                   case l of
                     []    -> (x,y)
                     le:[] -> (x, snd le)
                     _     -> error "Ambigious map, sorry... Programmer was too stupid error"
              ) cmps

applySubs :: [Rel] -> [Rel]
applySubs lst =
    let
        mp     = cmpsMap $ createSubsMap lst
        ap itm = case Map.lookup itm mp of
                   Just x  -> x
                   Nothing -> itm
    in
      map (\x ->
               Rel
               {
                 pa  = ap $ pa x
               , rel = rel x
               , pb  = ap $ pb x
               , pc  = ap $ pc x
               }
          ) lst

-- Filters out "Tri", "Dou", "S", "E"
verifySubs :: [Rel] -> [Maybe Rel]
verifySubs lst =
    foldl (\y x ->
           let
               a = pa x
               b = pb x
               c = pc x
               r = rel x
           in
             case r of
               "Tri" -> if (a == b && b == c) then
                            y
                        else Nothing:y
               "Dou" -> if (a == b && b /= c && a /= c) then
                            y
                        else Nothing:y
               "S"   -> if (a /= b && b /= c && a == c) then
                            y
                        else Nothing:y
               "E"   -> if (a /= b && b == c && a /= c) then
                            y
                        else Nothing:y
               _     -> if (a /= b && b /= c && a /= c) then
                            (Just x):y
                        else Nothing:y
        ) [] lst

invOp :: Rel -> Rel
invOp rl =
    let
        a = pa rl
        b = pb rl
        c = pc rl
        r = rel rl
    in
      Rel
      {
        pa = b
      , pb = a
      , pc = c
      , rel = case r of
                "R" -> "L"
                "L" -> "R"
                "B" -> "F"
                "I" -> "I"
                "F" -> "B"
      }

hmOp :: Rel -> Rel
hmOp rl =
    let
        a = pa rl
        b = pb rl
        c = pc rl
        r = rel rl
    in
      Rel
      {
        pa = b
      , pb = c
      , pc = a
      , rel = case r of
                "R" -> "R"
                "L" -> "L"
                "B" -> "I"
                "I" -> "F"
                "F" -> "B"
      }

hmiOp :: Rel -> Rel
hmiOp rl =
    let
        a = pa rl
        b = pb rl
        c = pc rl
        r = rel rl
    in
      Rel
      {
        pa = c
      , pb = b
      , pc = a
      , rel = case r of
                "R" -> "L"
                "L" -> "R"
                "B" -> "I"
                "I" -> "B"
                "F" -> "F"
      }

scOp :: Rel -> Rel
scOp rl =
    let
        a = pa rl
        b = pb rl
        c = pc rl
        r = rel rl
    in
      Rel
      {
        pa = a
      , pb = c
      , pc = b
      , rel = case r of
                "R" -> "L"
                "L" -> "R"
                "B" -> "B"
                "I" -> "F"
                "F" -> "I"
      }

sciOp :: Rel -> Rel
sciOp rl =
    let
        a = pa rl
        b = pb rl
        c = pc rl
        r = rel rl
    in
      Rel
      {
        pa = c
      , pb = a
      , pc = b
      , rel = case r of
                "R" -> "R"
                "L" -> "L"
                "B" -> "F"
                "I" -> "B"
                "F" -> "I"
      }

addPermutations :: [Rel] -> [Rel]
addPermutations scens =
    Set.toList $
    Set.fold (\scen lst ->
               Set.fromList [scen
                            ,invOp scen
                            ,scOp  scen
                            ,sciOp scen
                            ,hmOp  scen
                            ,hmiOp scen
                            ] `Set.union` lst
          )
    Set.empty $ Set.fromList scens

translateToAngles :: [Rel] -> [Equation]
translateToAngles scens =
    Set.toList $
    foldl (\lst scen ->
             let a = pa  scen
                 b = pb  scen
                 c = pc  scen
                 r = rel scen
             in
               (case r of
                 "L" -> Set.fromList $ [Less (Constant 0)  (Var (a,b,c))
                        ,Less (Var (a,b,c)) (Constant 180)
                        ,Equal (Addition (Var (a,b,c)) (Addition (Var (b,c,a)) (Var (c,a,b))))
                                   (Constant 180)
                        ,Equal (Var (a,b,c)) (Negation (Var (a,c,b)))
                        ] -- A B l C
                 "R" -> Set.fromList $ [Less (Var (a,b,c)) (Constant 0)
                        ,Less (Negation (Constant 180)) (Var (a,b,c))
                        ,Equal (Addition (Var (a,b,c)) (Addition (Var (b,c,a)) (Var (c,a,b))))
                               (Negation (Constant 180))
                        ,Equal (Var (a,b,c)) (Negation (Var (a,c,b)))
                        ] -- A B r C
                 "B" -> Set.fromList $ [Equal (Var (a,b,c)) (Constant 180)
                                       ,Equal (Var (b,c,a)) (Constant   0)
                                       ,Equal (Var (c,a,b)) (Constant   0)
                                       ,Equal (Addition (Var (a,b,c)) (Addition (Var (b,c,a))
                                               (Var (c,a,b)))) (Constant 180)
                                       ,Equal (Var (a,b,c)) (Var (a,c,b))
                        ] -- A B b C
                 "F" -> Set.fromList $ [Equal (Var (a,b,c)) (Constant   0)
                                       ,Equal (Var (b,c,a)) (Constant 180)
                                       ,Equal (Var (c,a,b)) (Constant   0)
                                       ,Equal (Addition (Var (a,b,c)) (Addition (Var (b,c,a))
                                               (Var (c,a,b)))) (Constant 180)
                                       ,Equal (Var (a,b,c)) (Var (a,c,b))
                        ] -- A B f C
                 "I" -> Set.fromList $ [Equal (Var (a,b,c)) (Constant   0)
                                       ,Equal (Var (b,c,a)) (Constant   0)
                                       ,Equal (Var (c,a,b)) (Constant 180)
                                       ,Equal (Addition (Var (a,b,c)) (Addition (Var (b,c,a))
                                               (Var (c,a,b)))) (Constant 180)
                                       ,Equal (Var (a,b,c)) (Var (a,c,b))
                        ] -- A B i C
               )
             `Set.union`
             (
              Set.fold (\acd acc ->
                  let lst =  filter (\st -> pa st == a && pb st == b && pc st == pc acd) scens
                  in
                      if lst == []
                      then
                          acc
                      else
                          let abd = head lst
                          in
                              Set.insert
                                  ( case (rel scen, rel acd, rel abd) of
                                      ("L", "L", "R") -> Equal (Addition (Var (a,b,c)) (Var (pa acd, pb acd, pc acd)))
                                                               (Addition (Var (pa abd, pb abd, pc abd)) (Constant 360))
                                      ("R", "R", "L") -> Equal (Addition (Var (a,b,c)) (Var (pa acd, pb acd, pc acd)))
                                                               (Addition (Var (pa abd, pb abd, pc abd))
                                                                             (Negation (Constant 360)))
                                      ("B", "B", "F") -> Equal (Addition (Var (a,b,c)) (Var (pa acd, pb acd, pc acd)))
                                                               (Addition (Var (pa abd, pb abd, pc abd)) (Constant 360))
                                      ("B", "B", "I") -> Equal (Addition (Var (a,b,c)) (Var (pa acd, pb acd, pc acd)))
                                                               (Addition (Var (pa abd, pb abd, pc abd)) (Constant 360))
                                      ("B", "L", "R") -> Equal (Addition (Var (a,b,c)) (Var (pa acd, pb acd, pc acd)))
                                                               (Addition (Var (pa abd, pb abd, pc abd)) (Constant 360))
                                      ("L", "B", "R") -> Equal (Addition (Var (a,b,c)) (Var (pa acd, pb acd, pc acd)))
                                                               (Addition (Var (pa abd, pb abd, pc abd)) (Constant 360))
                                      --("R", "B", "L") -> Equal (Addition (Var (a,b,c)) (Var (pa acd, pb acd, pc acd)))
                                      --                         (Addition (Var (pa abd, pb abd, pc abd)) (Constant 360))
                                      ("R", "R", "B") -> Equal (Addition (Addition (Var (a,b,c)) (Var (pa acd, pb acd, pc acd))) (Constant 360))
                                                               (Var (pa abd, pb abd, pc abd))
                                      (_, _, _)       -> Equal (Addition (Var (a,b,c)) (Var (pa acd, pb acd, pc acd)))
                                                                     (Var (pa abd, pb abd, pc abd)) )
                                  acc
                  )
                  Set.empty
                  ( Set.filter (\s -> pa s == a && pb s == c && pc s /= b) $ Set.fromList scens )
             )
             `Set.union` lst
        ) Set.empty scens

-- Some output stuff
getVariables :: [Equation] -> [Variable]
getVariables equs =
    Set.toList $ foldl (\x y -> (getVariablesHE y) `Set.union` x) Set.empty equs
       where
         getVariablesTE trm =
             case trm of
               Var v          -> Set.singleton v
               Constant _     -> Set.empty
               Addition t1 t2 -> (getVariablesTE t1) `Set.union` (getVariablesTE t2)
               Negation t     -> (getVariablesTE t)
               _              -> error "Nope!"
         getVariablesHE equ =
             case equ of
               Equal t1 t2 -> (getVariablesTE t1) `Set.union` (getVariablesTE t2)
               Less  t1 t2 -> (getVariablesTE t1) `Set.union` (getVariablesTE t2)
               LE    t1 t2 -> (getVariablesTE t1) `Set.union` (getVariablesTE t2)

showSMT :: [Equation] -> [Char]
showSMT lst =
    let
        tr   = map showSMTEq lst
        vars = foldl (++) "" $ map (\(x,y,z) -> ":extrafuns ((" ++ "v" ++ show x ++ "_" ++ show y ++ "_" ++
                                                show z ++ " Real))\n") $ getVariables lst
    in
      "(benchmark Triangles \n\n" ++
      ":logic QF_AUFLIA\n\n" ++
      vars ++ "\n\n:formula\n" ++
      (if length tr > 1 then
          foldl (\x y -> "(and \n" ++ x ++ " " ++ y ++ ")\n") (head tr) $  tail tr
        else
          if length tr > 0 then
              head tr
            else
                "") ++ "\n)"
        where
          showSMTEq eq =
              case eq of
                Equal t1 t2 -> "(= " ++ showSMTT t1 ++ " " ++ showSMTT t2 ++ ")"
                Less  t1 t2 -> "(< " ++ showSMTT t1 ++ " " ++ showSMTT t2 ++ ")"
                LE    t1 t2 -> "(<= " ++ showSMTT t1 ++ " " ++ showSMTT t2 ++ ")"

          showSMTT t =
              case t of
                Var (v1,v2,v3) -> "v" ++ show v1 ++ "_" ++ show v2 ++ "_" ++ show v3
                SVar     s     -> show s
                Constant c     -> show c
                Addition t1 t2 -> "(+ " ++ showSMTT t1 ++ " " ++ showSMTT t2 ++ ")"
                Negation t1    -> "(- 0 " ++ showSMTT t1 ++ ")"

parseOutputSMT :: String
               -> IO Bool
parseOutputSMT str =
    do
      let   sat = or $ map (\x -> "sat" `List.isPrefixOf` x) $ lines str
      let unsat = or $ map (\x -> "unsat" `List.isPrefixOf` x) $ lines str
      case (sat, unsat) of
        (True, False) -> return True
        (False, True) -> return False
        (_, _)        -> error $ "Help! Yices answered: " ++ str

-- Check for Triangle Consistency
runTC :: [Rel] -> IO Bool
runTC scen =
    do
      let subst    = verifySubs $ applySubs scen
      let failSubs = or $ map (== Nothing) subst
      if (failSubs)
       then
          do
            return False
       else
           if (subst == []) then
               return True
           else
               do
                 let angles   = translateToAngles $ addPermutations $
                                map fromJust subst
                 let str      = showSMT angles
                 writeFile "smt.smt" str
                 out <- readProcess "yices" ["-smt", "smt.smt"] ""
                 suc <- parseOutputSMT out
                 return suc

-- constraint network for testing
eris :: [Rel]
eris =  [ Rel 0 1 "L" 2
        , Rel 0 2 "L" 3
        , Rel 0 1 "R" 3
        , Rel 1 2 "R" 3
        , Rel 2 3 "R" 4
        ]
