import std.stdio, std.path, std.algorithm, std.file, std.regex, std.string, std.array, std.conv, std.functional, std.range, std.process;
import core.stdc.stdlib, std.exception, std.getopt;

void main( string[] args)
{

  bool recursively = false; 
  auto opts = getopt(
    args,
    std.getopt.config.caseSensitive,
    "r", "recursively edit", &recursively,
  );

  if ( opts.helpWanted)  defaultGetoptPrinter( "Usage: ",  opts.options );

    // имя файла создаваемой программы
	auto file = args.length > 1 ? args[1] : "";

   // Если имя файла программы *.d не указано
    if ( file.empty ){
      //usage instruction:
      stderr.writefln( "Usage: %s <file.d>" , args[0].baseName );

      // installing PATH instructions:
      executeShell( "which " ~ args[0].baseName ).output.empty &&
        stderr.writefln("Please add me to PATH:\nexport PATH=$PATH:%s" , args[0].dirName );

      exit(1);
    }

    // расширение файла
    string file_ex = file.extension.enforce.ifThrown("").replaceFirst(regex(`.`),"");


    // имя программы
    auto prgname = file.baseName.replace( regex(`\..+$`), "" );

	// какой editor
	auto editor = environment.get("CURLY_EDITOR" , "").strip;
	if ( editor==args[0].baseName ){
	  stderr.writefln("Not allowed %s as CURLY_EDITOR", editor);
	  exit(1);
	}else if( editor.empty ){  
	  editor = environment.get("EDITOR" , "").strip;
	}
	
	if ( editor.empty && file.exists ){
	  if ( auto editor_from_file = file.readText.matchFirst( `^\W*CURLY_EDITOR:\s*(.+)`.regex("m") ) ){
		editor = editor_from_file[1]; 
	  }
	} 

	if ( editor.empty ){
	  editor = userChoice("Choice editor", available_editors.array );
	  stderr.writeln("TIP: Set environment variable CURLY_EDITOR or EDITOR. f.e.: 'export CURLY_EDITOR=mcedit'");
	} 

	if (editor.empty){
	  exit(1);
	}
	
	if ( !file.exists ){

	  // найти шаблоны
	  string[] templates = dirEntries( thisExePath().dirName, SpanMode.shallow ).
	      filter!( f=>matchFirst( f.to!string , `.+\.tt`)).map!"a.to!string".array;

	  // имя файла шаблона, с которым работаем
	  string template_file_name;
	  
	  auto empty_name="Empty file";

	  if ( templates.empty ){
		template_file_name = empty_name;
	  }else  if (templates.length==1){
	    template_file_name = templates.front;
	  }else{
	    // если шаблонов несколько просим пользователя выбрать шаблон
	    template_file_name = userChoice("Select template", templates ~ empty_name );
	  }

	  auto prgText = template_file_name.exists ? 
		  template_file_name.readText.replaceAll( regex( r"\%prgname\%" ), prgname ) : 
		  "";

	  if (editor) 
		prgText = prgText ~ ("\n// CURLY_EDITOR: %s".format( editor));

	  std.file.write( file, prgText );
	
	} // - end of if !file.exists

	auto editCmd = "%s %s".format( editor, file);

	while( true ){	

	  auto lm = file.timeLastModified;
	  auto edPid = spawnShell( editCmd );
	  if ( edPid.wait != 0 )
		stderr.writefln("Was error while call editor command: %s.", editor );
	
	  string fileContent = file.readText;
	  //string fullFilePath = executeShell( "readlink -f " ~ file ).output;

	  // after edit:
	  auto templatedCmd = "";
	  if ( auto afterEditCmd = fileContent.matchFirst( `^\W*after-edit:\s*(.+)`.regex("m") ) ){
		  templatedCmd = afterEditCmd[1].to!string.replaceFirst( `%f`.regex, file );
	  }else{
		auto userCmd = userChoice( "Command for compile/check your file %s".format( file ), [] );
		if ( userCmd ) templatedCmd = userCmd.replaceFirst( file.regex, "%f" );
		file.append( "\n" ~ "// after-edit: " ~ templatedCmd ~ "\n" );
	  }
	  
	  //editor:
	  if ( !file.readText.matchFirst( `^\W*CURLY_EDITOR:\s*(.+)`.regex("m") ) )
		if (editor)  
		  file.append( "\n// CURLY_EDITOR: %s".format( editor) );
	  
	
	  if (templatedCmd) 
		if ( file.timeLastModified != lm )
		  spawnShell("set -x; " ~ templatedCmd ).wait;	
	  
	  if (!recursively) break;
	  writeln("Continue editing? [y]/n/Ctrl+c");
	  auto ans2 = readln.strip;
	  ans2 != "" && ans2!="y" && ans2!="Y" && exit(0); 
	}
}

auto available_editors(){
 auto editors = ["mcedit","emacs","vim","vi", "atom","sublimetext","nano","gedit","textadept"];
 return editors.filter!( editor => "which %s".format( editor ).executeShell.output.not!empty);
}

string userChoice ( string prompt, string[] list)
{
  auto answer = "";
  int i = 0;
  writeln( prompt );
  write("Type ");
  if ( !list.empty ) write(" type number or ");
  writeln( " text for custom and Enter:\n" );
  foreach ( number, elem; list.enumerate(1) ){
    writefln("%d: %s", number, elem);
  }
  answer = readln.strip;
  if ( matchFirst( answer, regex(`^\d+$`))){
	// user enters number
	i = answer.to!int - 1;
  }else{
	i = -1;
  }	

 if (i>=0){
  // number
  return list[i];
 }else{
  //custom
  return answer;
 }
}


// after-edit: dub --root=..

// CURLY_EDITOR: mcedit
