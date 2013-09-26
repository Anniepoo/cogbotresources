:- use_module(library(clpfd)).

:- discontiguous before/2, before_list/2, after_list/2.

%
%  Not part of the installer, but I wanted to work a toy problem
%  before the bundles

dishes([beverage, dessert, coffee, meat, potato, fish, corn, salad, soup, nuts]).


before(X, Y) :-
	before_list(X, List),
	member(Y, List).

before(X, Y) :-
	after_list(Y, List),
	member(X, List).

before(beverage, coffee).
before(beverage, dessert).

after_list(dessert, [meat, potato, corn, soup, fish]).

before(dessert, nuts).

before(meat, fish).
before(soup, meat).

before_list(soup, [meat, potato, fish, corn, dessert, beverage]).

before(dessert, nuts).
before(soup, salad).
before_list(salad, [meat, potato, fish, corn]).


cart :-
	dishes(DishNames),
	length(DishNames, N),
	make_dishes(N, DishNames, Dishes),
	maplist(dish_order, Dishes, DishOrderVars),
	all_distinct(DishOrderVars),
	order(Dishes, Dishes),
	labeling([], DishOrderVars),
	msort(Dishes, SortedDishes),
	write(SortedDishes),nl.

make_dishes(_N, [], []).

make_dishes(N, [HeadName|TailNames], [dish(Order, HeadName)|T]) :-
	Order in 1..N,
	make_dishes(N, TailNames, T).


order(_Dishes, []).
order(Dishes, [dish(Var, Name)|T]) :-
	order_one(Dishes, Var, Name),
	order(Dishes, T).

order_one([], _, _).
order_one([dish(DOrder, DName)|T] , Var , Name) :-
	before(DName, Name),
	DOrder #< Var,
	order_one(T, Var, Name).
order_one([_|T] , Var , Name) :-
	order_one(T, Var, Name).


dish_order(dish(Order, _Name), Order).




