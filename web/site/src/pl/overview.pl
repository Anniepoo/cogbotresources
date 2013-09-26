:- module(overview , []).
%
%  The home page for Cogbot website
%  discovers what prolog they're running,
%  and offers them a choice of cogbot's to install
%
:- use_module(library(http/html_write)).
:- use_module(library(http/http_dispatch)).
:- use_module(layout).


:- discontiguous component/1,
	component_name/2,
	component_description/2,
	component_depends/2,
	component_icon/2,
	component_icon_pos/2.

:- style_check(-atom).

:- http_handler(root(overview) , overview_page_handler, [id(overview)]).

overview_page_handler(_Request) :-
	reply_html_page(
	    cogbot_web_style,
	    html([title('Cogbot Overview')]),
	    overview_page_content).

overview_page_content -->
	 html([
	     h2('Overview'),
	     \paras([
'Cogbot is a framework for developing intelligent robots in real and virtual worlds.',
'While our long term goal is to support a number of both physical and virtual robots, at the moment our emphasis our primary supported platform is virtual robots in virtual worlds that use the Second Life protocol (Second Life and Opensimulator). We currently have one physical robot user (<a ref="https://hansonrobotics.wordpress.com/">Hansen Robotics</a>), and are looking to support more physical robots in the future.',
'Cogbot is a framework.	The core provides basic functionality, but most of the power is in the plugins.',
'While Cogbot is suitable for serious applications in robotics and AI, beginning with Cogbot is fun and easy.',
'AI researchers looking for a platform that integrates many standard components including embodiment will find Cogbot the best developed offering available.',
'Software engineers creating presences in virtual worlds will find Cogbot the obvious choice.',
'Virtual world users will find Cogbot a cool way to make bots even with minimal or no programming experience. Educators will find Cogbot a useful teaching tool. Content creators will find Cogbot useful for automating tasks in shop and studio. Cogbot bots can be NPC\'s in RP Sims. If it needs a bot, it needs Cogbot.'
		   ]),
	    \components_list
       ]).

components_list -->
	{
	   bagof(Name, component(Name), Components),
	   maplist(as_entry, Components, ComponentsHTML)
	},
	html(ComponentsHTML).

as_entry(Name, \component_entry(Name)).

component_entry(Name) -->
	{
	    component_name(Name, HumanName),
	    component_description(Name, Description)
	},
	html([
	    div(class=component, [
	        h3(HumanName),
		html(Description)
				 ])
	     ]).

%%%%%%%%%%%%%%%%%%%%%%%%%  Component Definitions %%%%%%%%%%%%%%%%%%%%%%%
%
%	Todo this is shared with the installer, sort of, it's not very DRY, but
%	I'm not up for making the projects linked at the moment.
%	(notice that these are missing the status code, present in
%	installer)

%
%  core
%
component(core).
component_name(core, 'Cogbot Core').
component_icon_pos(core, '0 0').
component_description(core,
[p('The basics of Cogbot. Interact with the bot in the virtual world via botcmd language, or via a telnet or http interface with the headless cogbot process.'),
 p('Almost all users will require this component.')]).

%
%   prolog
%
component(prolog).
component_name(prolog, 'SWI-Prolog For Cogbot').
component_icon_pos(prolog, '404px 44px').
component_description(prolog,
[p([], ['Support for ', a([href='http:swi-prolog.org'], 'swi-prolog'),
	'. This is the connection between swi-Prolog and Cogbot. Install swi-Prolog first if needed.']),
 p([], ['Supports programming the bot in Prolog.']),
 p([], ['Most users will want this component, as Prolog is the primary language for programming Cogbot.'])]).
component_depends(prolog, core).

%
%  radegast
%
component(radegast).
component_name(radegast, 'Radegast Metaverse Client').
component_icon_pos(radegast, '0px 0px').
component_description(radegast,
[p([], 'This special version is integrated with Cogbot.'),
 p([], ['Most bots require some amount of manual control for setup and debugging.']),
 p([], 'Radegast is a text based viewer for manually controlling the bot. Almost all desktop installs should include Radegast.')]).
component_depends(radegast, core).

%
%  aiml
%
component(aiml).
component_name(aiml, 'AIMLbot AIML Interpreter').
component_icon_pos(aiml, '400px 0px').
component_description(aiml,
[p([], ['An environmentally aware interpreter for ',
	a([href='http://www.alicebot.org/TR/2005/WD-aiml/'], 'AIML.')]),
 p([], ['Patterns can match against conditions in the world, and AIML templates are able to issue botcmd commands.']),
 p([], ['AIMLbot can query Cyc to infer facts. So, for example, people named Sue are usually women, so the bot may respond differently to Sue and George. A separate component makes Cyc world aware.']),
 p([], ['AIMLbot can use WordNet (a separate component) to match patterns against synonyms.']),
 p([], 'AIMLbot includes Lucene, a triple store database. Using Lucene, AIMLbot can persist information without ontologizing it. For example:'),
 ul([], [
     li([], 'User: "Joe likes sports movies"'),
     li([], '...(later)...'),
     li([], 'User: "What does Joe like?"'),
     li([], 'Bot: "sports movies"')]),
 p([], 'Users who want their bots to listen and speak will want this component.')
]).

component_depends(aiml, core).
% oh though .. aimlbot need a cyc config url even when cyc client not
% selected  - aimlbot can query ext. server

%
%  aiml_personality
%
component(aiml_personality).
component_name(aiml_personality, 'AIML Personality Files').
component_icon_pos(aiml_personality, '460px 8px').
component_description(aiml_personality,
[p('AIML files for an Alice based starter personality.'),
 p('This personality simulates a current day western culture adult.'),
 p('AIML users will want this component unless they have another personality.')]).
component_depends(aiml_personality, aiml).

%
%  wordnet
%
component(wordnet).
component_name(wordnet, 'WordNet Lexical Database Support').
component_description(wordnet,
[p(['Improves AIML pattern matching by matching synonyms. So an AIML pattern that contains the word ',
   em([], 'sofa'), ' would match ', em([], 'divan'),
   ' in an utterance.']),
 p('AIMLbot users will find this component nifty.')]).
component_depends(wordnet, aiml).
% TODO include the wordnet license

%
%   opencyc
%
component(opencyc).
component_name(opencyc, 'OpenCyc Client').
component_description(opencyc,
[p([], 'Integrated Cyc client which automatically pushes information about the virtual world to the external Cyc database.'),
 p([], 'Users who wish to use an external Cyc server should install this component.')]).
component_depends(opencyc, core).

%
%   irc
%
component(irc).
component_name(irc, 'Internet Relay Chat Relay').
component_description(irc,
[p([], 'Relays chat between an IRC channel and the bot. Relay allows control of the bot via irc.'),
 p([], 'This is useful for long term monitoring and control of production bots. Users who will be operating an unattended bot should consider using this tool.')]).
component_depends(irc, core).

%
%   lisp
%
component(lisp).
component_name(lisp, 'Common Lisp Interface').
component_icon_pos(lisp, '250px 35px').
component_description(lisp,
[p('Version of ABCL Common Lisp adapted to control the bot and know about the bot\'s environment.'),
 p('Lisp users will want to install this component.')
 ]).
component_depends(lisp, core).

%
%    sims
%
component(sims).
component_name(sims, 'The Sims').
component_icon_pos(sims, '120px 35px').
component_description(sims,
[p([
     'The Sims module loops through objects looking for affordances offered by the type system',
     'and ',
     &(quot),
     'uses',
     &(quot),
     'the one that best meets it',
     &(apos),
     's needs.']),
 p('Users who want to use affordances and types based AI should install this component.'),
 p('So should those who just want to see a really cool demo of Cogbot.')]).
component_depends(sims, core).

%
%   examples
%
component(examples).
component_name(examples, 'Examples').
component_description(examples,
[p('Example files. Examples require various support services depending on the specific example.'),
 p('Users new to Cogbot will appreciate the examples.')]).

%
%   docs
%
component(docs).
component_name(docs, 'Documentation').
component_description(docs,
[p('User Documentation Bundle.'),
 p('Some day this will be a robot lead series of courses on Cogbot and AI generally,'),
 p(['but for the moment it',
    &(apos),
    's just as likely to be a badly formatted Word doc.'])]).

%
%  objects
%
component(objects).
component_name(objects, 'Cogbot Virtual Objects').
component_description(objects,
[p('Virtual objects for use with Cogbot.'),
 ul([
     li('Tools Cogbot uses for the sim iterator'),
     li('the test suite tools'),
     li('and a cool Cogbot avatar.')])]).


%%%%%%%%%%%%%%%%%%%%%%%%  Defaults

component_icon(Name, FileName) :-
	atomic_list_concat(['/f/', Name, '.png'], FileName).
component_icon_pos(_, '0px 0px').

