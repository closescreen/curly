import std.stdio, std.path, std.algorithm, std.file, std.regex, std.string, std.array, std.conv, std.functional, std.range, std.process;
import core.stdc.stdlib;

void main( string[] args)
{
    // имя файла создаваемой программы
	auto file = args.length > 1 ? args[1] : "";

    // Если имя файла программы *.d не указано
    if ( file.empty ){
  	  stderr.writefln( "Usage: %s <file.d>" , args[0].baseName ); 
  	  // installing
	  auto pathToMe = executeShell( "which " ~ args[0].baseName );
	  if ( pathToMe.output.empty )
		stderr.writeln("Please add me to PATH:\nexport PATH=$PATH:" , args[0].dirName );
		exit(1);
	}

	// расширение файла
	string file_ex;
	if ( auto m = matchFirst( file, `\.(.+)$` ))
          file_ex = m[1];	

    // имя программы
    auto prgname = file.baseName.replace( regex(`\..+$`), "" );

	// найти/создать setting dir
	auto home = environment.get("HOME","");
	auto settings_dir = home.empty ? "" : buildPath( home, ".curly");
	if ( !settings_dir.exists ){
	  settings_dir.mkdir;
	  stderr.writefln("%s was created.", settings_dir);
	}

	if ( !file.exists ){

	
	  // найти/создать шаблон[ы]
	  string[] templates;
	  if ( settings_dir )
	    templates = dirEntries( settings_dir, SpanMode.shallow ).
		  filter!( f=>matchFirst( f.to!string , `.+\.%s\.tt`.format(file_ex))).map!"a.to!string".array;
	
	  if ( templates.empty ){
	    // ищем шаблоны из коробки

	    auto inbox_templates = dirEntries( thisExePath().dirName, SpanMode.shallow ).
	      filter!( f=>matchFirst( f.to!string , `.+\.tt`)).map!"a.to!string".array;

	    // копируем шаблоны в settings_dir
	    foreach( t; inbox_templates ){
	      auto to = buildPath( settings_dir, t.baseName );
	      copy( t, to);
	      stderr.writefln("%s copyed to %s for you.", t, to);
	    }
	    
	    // снова ищем шаблоны в settings_dir
	    templates = dirEntries( settings_dir, SpanMode.shallow ).
		  filter!( f=>matchFirst( f.to!string , `.+\.%s\.tt`.format(file_ex))).map!"a.to!string".array;
	  }  

	  // имя файла шаблона, с которым работаем
	  string template_file_name;
	  
	  // теперь есть подходящий шаблон?
	  if ( templates.empty ){    
	    // записываем шаблон template_file_name в settings_dir
	    template_file_name = buildPath( settings_dir, "sample.%s.tt".format(file_ex) );
	    std.file.write( template_file_name, template_text( file_ex, "" ) );
	    stderr.writefln( "Template %s created. You may edit it.", template_file_name);
	  }else  if (templates.length==1){
	    template_file_name = templates.front;
	  }else{
	    // если шаблонов несколько просим пользователя выбрать шаблон
	    template_file_name = userChoice("Select template", templates);
	  }

	  auto prgText = template_file_name.readText.replaceAll( regex( r"\%prgname\%" ), prgname );
	  std.file.write( file, prgText );
	
	} // - end of if !file.exists
	
	// какой editor
	auto editor = environment.get("CURLY_EDITOR" , "");
	if ( editor==args[0].baseName ){
	  stderr.writefln("Not allowed %s as CURLY_EDITOR", editor);
	  exit(1);
	}else if( editor.empty ){  
	  editor = environment.get("EDITOR" , "");
	} 
	if (editor.empty){
	  editor = userChoice("Choice editor", available_editors.array );
	  stderr.writeln("TIP: Set environment variable CURLY_EDITOR or EDITOR. f.e.: 'export CURLY_EDITOR=mcedit'");
	} 
	if (editor.empty){
	  exit(1);
	}
	
	// открыть файл в редакторе EDITOR  
	auto editCmd = "%s %s".format( editor, file);
	//stderr.writeln( editCmd);
	auto edPid = spawnShell( editCmd );
	if ( edPid.wait != 0 )
	  stderr.writefln("Was error while call editor command: %s.", editor );
	
	string fileContent = file.readText;
	string fullFilePath = executeShell( escapeShellCommand( "readlink -f " ~ file )).output;
	bool isDubSingle;
	isDubSingle = !matchFirst( fileContent, regex(`^\s*(dub\.json|dub\.sdl):\s*\n`, "m")).empty;
	
	
	string cmd;
	string[] cmd_opts;
	if (isDubSingle)
  	  cmd = `set -v; dub build --single ` ~ file;
  	else if ( file_ex == "d" ){
  	  cmd = userChoice("Select command:", [
  		"dmd -unittest " ~ file,
  		"dmd -main -unittest " ~ file,
  		"dmd -main -unittest -run " ~ file,
  		"dmd " ~ file,
  	  ]);
  	}  
  	  
  	if (cmd){
      auto buildPid = spawnShell( cmd );
	  buildPid.wait;	
	}	
}

string template_text( string ext, lazy string otherwise ){
if ( ext=="d" ) return 
`/+
dub.json:
{
	"name": "%prgname%",
	"authors": [
		""
	],
	"dependencies": {
	},
	"description": "",
	"copyright": "",
	"license": ""

}
+/
module %prgname%;
import std.stdio, std.getopt, std.string, std.regex,
	std.algorithm, std.array, std.conv, std.range, std.functional,
	std.file, std.path, std.process,
	std.format, std.csv, std.xml, std.zip, std.zlib, std.json,
	std.uri, std.uni,  std.utf,	std.ascii, std.base64,
    std.system, std.traits, std.typecons,
    std.datetime, std.demangle, std.digest.md, std.encoding, std.exception,
    std.bigint, std.bitmanip, std.compiler, std.complex, std.concurrency, std.container, 
    std.math, std.mathspecial, std.mmfile,
    std.numeric, std.outbuffer, std.parallelism, 
    std.random,  std.signals, std.socket,
    std.stdint, std.windows.syserror, 
    std.typetuple,  std.variant ;

void main( string[] args )
{
  writefln("Ok");
}
`;

else return otherwise;
}

auto available_editors(){
 auto editors = ["mcedit","emacs","vim","vi", "atom","sublimetext","nano","gedit","textadept"];
 return editors.filter!( editor => "which %s".format( editor ).executeShell.output.not!empty);
}

string userChoice ( string prompt, string[] list)
{
 auto answer = "";
 auto i = 0;
 while ( !matchFirst( answer, `\d+`) || i<0 || i>=list.length ){
  stderr.writefln( "%s (type number and Enter):\n", prompt );
  foreach ( number, elem; list.enumerate(1) ){
    writefln("%d: %s", number, elem);
  }
  answer = readln.strip;
  i = answer.to!int - 1;
 }
 return list[i];  
}
