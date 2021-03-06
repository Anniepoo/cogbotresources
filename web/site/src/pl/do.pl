:- module(do, []).

%
%  This is the page that's displayed while we actually do the install.
%  Actual install is in execute
%


:- use_module(library(http/html_write)).
:- use_module(library(http/http_dispatch)).
:- use_module(layout).
:- use_module(bundle).
:- use_module(execute).


:- http_handler(root(do) ,
		start_and_redir_to_do,
		[id(do)]).

start_and_redir_to_do(Request) :-
	memberchk(search(Config), Request),
	bundle_install_plan(Plan),
	do_plan_in_thread(Plan, Config),
	http_redirect(moved_temporary, location_by_id(dopage), Request).

:- http_handler(root(dopage) ,
		do_page_handler,
		[id(dopage)]).

do_page_handler(_Request) :-
	reply_html_page(
	    cogbot_web_style_refresh,
	    html([title('Being Invaded By Robot Overlords')]),
	    \do:do_page_content).

do_page_content -->
	{
	   done_so_far(Plan),
	   maplist(do:bundle_done_html, Plan, PlanHTML)
	},
	html([
	    h2('Done So Far'),
	    div([id=bundlebox],
		[ol([id=plan_list], PlanHTML)
		]),
	    \action_bar(do:do_buttons)
	     ]).

bundle_done_html(X, \bundle_section(X)).

do_buttons -->
	html([
	    \wizard_button(reset, 'Cancel The Installation'),
	    \wizard_button_default(reset, 'Finish Installation')
	     ]).


