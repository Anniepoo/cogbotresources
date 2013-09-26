:- module(cogbotsite , [cogbotsite/1]).
%
%%	 not using this code. I'm going to steal code from
%  Raivo's blog code
%
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_error)).
:- use_module(library(debug)).
:- use_module(library(http/html_write)).
:- use_module(library(http/http_parameters)).
:- use_module(library(url)).
:- use_module(library(sgml)).

% turns on sessions
:- use_module(library(http/http_session)).

% The predicate cogbotsite(?Port) starts the server. It simply creates a
% number of Prolog threads and then returns to the toplevel, so you can
% (re-)load code, debug, etc.
cogbotsite(Port) :-
        http_server(http_dispatch, [port(Port), workers(1)]),
	thread_get_message(_),
	halt.

% define the root of our web system
web_root(X) :- X = '.'. % '/home/annie/prologclass/fromwindows'.
% convert path names and URIs for files
web_path(Relative,Absolute) :- web_root(Root),
	atom_concat(Root, Relative, Absolute).
%  handle static pages.
/* See
http://old.nabble.com/How-to-load-an-image-into-a-web-page-with-swi-prolog-td14363488.html
Supposedly this handles everything in ./pages/ but it makes the compiler
freak
dec 12,2010 ao it's working now
*/
:- http_handler( '/pages' , serve_page, [prefix]).
:- http_handler( '/font' , serve_page, [prefix]).
:- http_handler( '/style' , serve_page, [prefix]).


:- http_handler(root(.),
                http_redirect(moved, root(index)),
                []).

% handle 404's
% swi uses the longest handler that matches
:- http_handler(/, http_404([index('/pages/404.html')]),
                [prefix]).

serve_page(Request) :-
        memberchk(path(Path), Request),
	web_path(Path, FilePath),
	http_reply_file(FilePath, [], Request).


% TODO figure out how to organize site!
:- http_handler('/index.html' , http_redirect(moved, root(index)), []).
:- http_handler(root(index) , display_index, []).

% home page
display_index(Request) :-
	reply_html_page([title('end'),
			 meta(['http-equiv' = refresh, content = M] , []),
			 link([rel=stylesheet,
			       type='text/css',
			       href=Style], [])],
			 [h1('End of quiz'),
			  p([class=end],
			    [a([href=Link], 'Click to start quiz')])]).

% display a question handler
display_question(Request) :-
	http_parameters(Request,
			/*
			[qnum(Question_Number ,
					 [ default(0),
					   between(0,50),
					   integer ]),  */
			 % workaround for swipl bug
			 [qnum(Question_Number_Atom , []),
			 quiz(Quiz_Name , [])], []),
	atom_number(Question_Number_Atom, Question_Number),
	readquiz:question_db(Quiz_Name, Question_Number, Style , Question),
	question_html(Quiz_Name,
		      Question_Number,
		      Question ,
		      Html),
	make_timeout_meta(Quiz_Name , M),
	append_reset_button(Html , Quiz_Name , NHtml),
	reply_html_page([title('quiz'),
			 meta(['http-equiv' = refresh, content = M] , []),
			 link([rel=stylesheet,
			       type='text/css',
			       href=Style], [])],
			 NHtml).

% display a response handler
display_feedback(Request) :-
	http_parameters(Request,
			/*
			[qnum(Question_Number ,
					 [ default(0),
					   between(0,50),
					   integer ]),  */
			 % workaround for swipl bug
			 [qnum(Question_Number_Atom , []),
			 quiz(Quiz_Name , []),
			 a(Answer, [])],
			[]),
	atom_number(Question_Number_Atom, Question_Number),
	readquiz:question_db(Quiz_Name,
		    Question_Number,
		    Style,
		    question(_, Answers, Feedback)),
	Next_Question is Question_Number + 1,
	memberchk(correct(Rubric) , Answers),% barfs if we don't have one 8cD
	(
	    readquiz:question_db(Quiz_Name, Next_Question , _, _)  ->
	    swritef(NextRef , 'q?quiz=%w&qnum=%w' ,
		    [Quiz_Name, Next_Question]);
	    swritef(NextRef , 'e?quiz=%w' ,[Quiz_Name])
	),
	swritef(ARubric, '%w', [Rubric]),
	swritef(AAnswer, '%w', [Answer]),
	generate_feedback_html(
			       Feedback ,
			       AAnswer ,
			       ARubric ,
			       NextRef ,
			       Html),
	make_timeout_meta(Quiz_Name , M),
	append_reset_button(Html , Quiz_Name , NHtml),
	reply_html_page([title('feedback'),
			 meta(['http-equiv' = refresh, content = M] , []),
			 link([rel=stylesheet,
			       type='text/css',
			       href=Style], [])],
			 NHtml).

append_reset_button(Html , Quiz_Name , FullHtml) :-
	swritef(ALink , 'q?quiz=%w&qnum=0' , [Quiz_Name]),
	append(Html , [p([class=restart] , a([href=ALink] , 'Restart Quiz'))] , FullHtml).

% generate the in-body HTML for a feedback page
% +Feedback, the feedback param, default or an atom to use
% +AAnswer   the answer as a string
% +ARubric   the rubric as a string
% +NextRef   href for the next question
% -Html      the generated Html
%
% correct answer
generate_feedback_html(_ , A , A, NextRef , Html) :-
	Html = [div([class=good] ,
		   [
		      h1('Yes,'),
		      p(A),
		      p('is correct'),
		      p(a([href=NextRef], 'Next'))
		   ])].

% incorrect answer, default feedback
generate_feedback_html(default , AAnswer , ARubric, NextRef , Html) :-
	AAnswer \== ARubric,
	Html = [div([class=bad] ,
		   [
		      h1('No,'),
		      p(AAnswer),
		      p('is incorrect'),
		      p(ARubric),
		      p('is the correct answer'),
		      p(a([href=NextRef], 'Next'))
		   ])].

% incorrect answer, custom feedback
generate_feedback_html(Feedback , AAnswer , ARubric, NextRef , Html) :-
	AAnswer \== ARubric,
	swritef(AFeedback , '%w' , [Feedback]),
	Html = [div([class=bad] ,
		   [
		      h1('No,'),
		      p(AAnswer),
		      p('is incorrect'),
		      p(ARubric),
		      p('is the correct answer because'),
		      p(AFeedback),
		      p(a([href=NextRef], 'Next'))
		   ])].

% unifies if the fourth arg is the swi-ish HTML representation of the
% third arg

question_html(Quiz_Name, Question_Number,
	      question(Question_Text, Answers , _) ,
	      [h1(Question_Text)|AHtml]) :-
	links_for_question(Quiz_Name,
			   Question_Number,
			   Link_Stub),
	question_answers(Link_Stub,
			 Answers,
			 AHtml).

% actually, we should do all this in the feedback, not the question
%  Similarly, it'd more modular, and avoids the security issue, if we
%  handle evaluation in the feedback
links_for_question(Quiz_Name,
		   Question_Number,
		   Link_Stub
		  ) :-
	swritef(Link_Stub , 'fb?quiz=%w&qnum=%w&a=',
		[Quiz_Name, Question_Number]).

% unifies if the second arg is the swi-ish HTML representation of the
% set of answers as links
question_answers(Link_Stub,
		 Answers , Ctrls) :-
	answer_controls(Link_Stub,
			Answers ,
			Ctrls ,  []).

% unifies if the fourth and fifth args are a difference list of the
% swi-ish HTML generated from the answers given in the third arg
answer_controls(_, [], _, []).
answer_controls(Link_Stub,
		[correct(H)|T] ,
		[CH|CT] ,
		Rest) :-
	answer_controls_raw(Link_Stub,
			[H|T],
			[CH|CT],
			Rest).
answer_controls(Link_Stub,
		[incorrect(H)|T] ,
		[CH|CT] ,
		Rest) :-
	answer_controls_raw(Link_Stub,
			[H|T],
			[CH|CT],
			Rest).

answer_controls_raw(Link_Stub, [H|T] , [CH|CT] , Rest) :-
	www_form_encode(H , URLH),
	swritef(Link , '%w%w' , [Link_Stub , URLH]),
	CH = p(a([href=Link], H)),  % TODO test that this works with entities
	answer_controls(Link_Stub, T , CT , Rest).

















































