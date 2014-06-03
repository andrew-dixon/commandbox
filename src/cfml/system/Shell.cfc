/**
*********************************************************************************
* Copyright Since 2005 ColdBox Platform by Ortus Solutions, Corp
* www.coldbox.org | www.ortussolutions.com
********************************************************************************
* @author Brad Wood, Luis Majano, Denny Valliant
* The CommandBox Shell Object that controls the shell
*/
component accessors="true" singleton {

	// DI
	property name="print" 				inject="print";
	property name="commandService" 		inject="CommandService";
	property name="readerFactory" 		inject="ReaderFactory";
	property name="system" 				inject="system";
	property name="initialDirectory" 	inject="userDir";
	property name="homeDir" 			inject="homeDir";
	property name="tempDir" 			inject="tempDir";
	property name="CR" 					inject="CR";
	property name="formatterUtil" 		inject="Formatter";
	property name="logger" 				inject="logbox:logger:{this}";
	property name="fileSystem"			inject="fileSystem";

	/**
	* The java jline reader class.
	*/
	property name="reader";
	/**
	* The shell version number
	*/
	property name="version";
	/**
	* Bit that tells the shell to keep running
	*/
	property name="keepRunning" default="true" type="Boolean";
	/**
	* Bit that is used to reload the shell
	*/
	property name="reloadShell" default="false" type="Boolean";
	/**
	* The Current Working Directory
	*/
	property name="pwd";
	/**
	* The default shell prompt
	*/
	property name="shellPrompt";

	/**
	 * constructor
	 * @inStream.hint input stream if running externally
	 * @outputStream.hint output stream if running externally
 	**/
	function init( inStream, outputStream ) {

		// Version is stored in cli-build.xml. Build number is generated by Ant.
		// Both are replaced when CommandBox is built.
		variables.version = "@build.version@.@build.number@";
		// Init variables.
		variables.keepRunning 	= true;
		variables.reloadshell 	= false;
		variables.pwd 			= "";
		variables.reader 		= "";
		variables.shellPrompt 	= "";
		
		// Save these for onDIComplete()
		variables.initArgs = arguments;
						
    	return this;
	}

	/**
	 * Finish configuring the shell
	 **/
	function onDIComplete() {
		variables.pwd 	 		= initialDirectory;
		variables.reader 		= readerFactory.getInstance( argumentCollection = variables.initArgs  );
		variables.shellPrompt 	= print.green( "CommandBox> ");
		
		// set and recreate temp dir
		setTempDir( variables.tempdir );
		
		// load commands
		variables.commandService.configure();
	}

	/**
	 * sets exit flag
	 **/
	function exit() {
    	variables.keepRunning = false;
		return "Peace out!";
	}


	/**
	 * sets reload flag, relaoded from shell.cfm
	 * @clear.hint clears the screen after reload
 	 **/
	function reload(Boolean clear=true) {
		if( arguments.clear ){
			reader.clearScreen();
		}
		variables.reloadshell = true;
    	variables.keepRunning = false;
	}

	/**
	 * returns the current console text
 	 **/
	function getText() {
    	return reader.getCursorBuffer().toString();
	}

	/**
	 * sets prompt
	 * @text.hint prompt text to set
 	 **/
	function setPrompt(text="") {
		if(text eq "") {
			text = variables.shellPrompt;
		} else {
			variables.shellPrompt = text;
		}
		reader.setPrompt( variables.shellPrompt );
		return "set prompt";
	}

	/**
	 * ask the user a question and wait for response
	 * @message.hint message to prompt the user with
 	 **/
	function ask( message ) {
		var input = "";
		input = reader.readLine( message );
		// Reset back to default prompt
		setPrompt();
		return input;
	}


	/**
	 * Wait until the user's next keystroke
	 * @message.message An optional message to display to the user such as "Press any key to continue."
 	 **/
	function waitForKey( message='' ) {
		var key = '';
		if( len( arguments.message ) ) {
			printString( arguments.message );
    		reader.flush();
		}
		key = reader.readCharacter();
		// Reset back to default prompt
		setPrompt();
		return key;
	}

	/**
	 * clears the console
	 *
	 * Almost works on Windows, but doesn't clear text background
	 * 
 	 **/
	function clearScreen( addLines = true ) {
	// This outputs a double prompt due to the redrawLine() call
	//	reader.clearScreen();
	
		// A temporary workaround for windows. Since background colors aren't cleared
		// this will force them off the screen with blank lines before clearing.
		if( variables.fileSystem.isWindows() && addLines ) {
			var i = 0;
			while( ++i <= getTermHeight() + 5 ) {
				reader.println();	
			}
		}
		
		reader.print( '[2J' );
		reader.print( '[1;1H' );
		
	}

	/**
	 * Get's terminal width
  	 **/
	function getTermWidth() {
       	return getReader().getTerminal().getWidth();
	}

	/**
	 * Get's terminal height
  	 **/
	function getTermHeight() {
       	return getReader().getTerminal().getHeight();
	}

	/**
	 * returns the current directory
  	 **/
	function pwd() {
    	return pwd;
	}

	/**
	 * sets the shell home directory
	 * @directory.hint directory to use
  	 **/
	function setHomeDir( required directory ){
		variables.homedir = directory;
		setTempDir( variables.homedir & "/temp" );
		return variables.homedir;
	}

	/**
	 * returns the shell home directory
  	 **/
	function getHomeDir() {
		return variables.homedir;
	}

	/**
	 * returns the shell artifacts directory
  	 **/
	function getArtifactsDir() {
		return getHomeDir() & "/artifacts";
	}

	/**
	 * sets and renews temp directory
	 * @directory.hint directory to use
  	 **/
	function setTempDir(required directory) {
        lock name="clearTempLock" timeout="3" {
		    variables.tempdir = directory;
		        
        	// Delete temp dir
	        var clearTemp = directoryExists(directory) ? directoryDelete(directory,true) : "";
	        
	        // Re-create it. Try 3 times.
	        var tries = 0;
        	try {
        		tries++;
		        directoryCreate( directory );
        	} catch (any e) {
        		if( tries <= 3 ) {
					logger.info( 'Error creating temp directory [#directory#]. Trying again in 500ms.', 'Number of tries: #tries#' );
        			// Wait 500 ms and try again.  OS could be locking the dir
        			sleep( 500 );
        			retry;
        		} else {
					logger.info( 'Error creating temp directory [#directory#]. Giving up now.', 'Tried #tries# times.' );
        			printError(e);        			
        		}
        	}
        }
    	return variables.tempdir;
	}

	/**
	 * returns the shell temp directory
  	 **/
	function getTempDir() {
		return variables.tempdir;
	}

	/**
	 * changes the current directory
	 * @directory.hint directory to CD to
  	 **/
	function cd(directory="") {
		directory = replace(directory,"\","/","all");
		if(directory=="") {
			pwd = initialDirectory;
		} else if(directory=="."||directory=="./") {
			// do nothing
		} else if(directoryExists(directory)) {
	    	pwd = directory;
		} else {
			return "cd: #directory#: No such file or directory";
		}
		return pwd;
	}

	/**
	 * prints string to console
	 * @string.hint string to print (handles complex objects)
  	 **/
	function printString(required string) {
		if(!isSimpleValue(string)) {
			systemOutput("[COMPLEX VALUE]\n");
			writedump(var=string, output="console");
			string = "";
		}
    	reader.print(string);
    	reader.flush();
	}

	/**
	 * runs the shell thread until exit flag is set
	 * @input.hint command line to run if running externally
  	 **/
    function run( input="" ) {
        var mask 	= "*";
        var trigger = "su";
        
		// init reload to false, just in case
        variables.reloadshell = false;

		try{
	        // Get input stream
	        if( arguments.input != "" ){
	        	 arguments.input &= chr(10);
	        	var inStream = createObject( "java", "java.io.ByteArrayInputStream" ).init( arguments.input.getBytes() );
	        	reader.setInput( inStream );
	        }

	        // setup bell enabled + keep running flags
	        reader.setBellEnabled( true );
	        variables.keepRunning = true;

	        var line ="";
			// Set default prompt
			setPrompt();

			// while keep running
	        while( variables.keepRunning ){
	        	// check if running externally
				if( input != "" ){
					variables.keepRunning = false;
				}

				try {
					// Shell stops on this line while waiting for user input
		        	line = reader.readLine();
				} catch( any er ) {
					printError( er );
					continue;
				}

	            // If we input the special word then we will mask the next line.
	            if( ( !isNull( trigger ) ) && ( line.compareTo( trigger ) == 0 ) ){
	                line = reader.readLine( "password> ", javacast( "char", mask ) );
	            }

	            // If there's input, try to run it.
				if( len( trim( line ) ) ) {
					try{
						callCommand( line );
					} catch (any e) {
						printError( e );
					}
				}
				
				// Flush history buffer to disk. I could do this in the quit command
				// but then I would lose everything if the user just closes the window
				getReader().getHistory().flush();
				
	        } // end while keep running

		} catch( any e ){
			SystemOUtput( e.message & e.detail );
			printError( e );
		}
		return variables.reloadshell;
    }

	/**
	 * call a command
 	 * @command.hint command name
 	 **/
	function callCommand( String command="" )  {
		var result = commandService.runCommandLine( command );
		if(!isNull( result ) && !isSimpleValue( result )) {
			if(isArray( result )) {
				return reader.printColumns(result);
			}
			result = formatterUtil.formatJson( serializeJSON( result ) );
			printString( result );
		} else if( !isNull( result ) && len( result ) ) {
			printString( result );
			// If the command output text that didn't end with a line break one, add one
			if( mid( result, len( result ), 1 ) != CR ) {
				getReader().println();
			}
		}
	}


	/**
	 * print an error to the console
	 * @err.hint Error object to print (only message is required)
  	 **/
	function printError(required err) {
		logger.error( '#err.message# #err.detail ?: ''#', err.stackTrace ?: '' );
		reader.print(print.boldRedText( "ERROR: " & formatterUtil.HTML2ANSI(err.message) ) );
		reader.println();
		if( structKeyExists( err, 'detail' ) ) {
			reader.print(print.boldRedText( formatterUtil.HTML2ANSI(err.detail) ) );
			reader.println();
		}
		if (structKeyExists( err, 'tagcontext' )) {
			var lines=arrayLen( err.tagcontext );
			if (lines != 0) {
				for(idx=1; idx<=lines; idx++) {
					tc = err.tagcontext[ idx ];
					if (len( tc.codeprinthtml )) {
						if( idx > 1 ) {
							reader.print( print.boldCyanText( "called from " ) );
						}
						reader.print(print.boldCyanText( "#tc.template#: line #tc.line##CR#" ));
						reader.print( print.text( formatterUtil.HTML2ANSI( tc.codeprinthtml ) ) );
					}
				}
			}
		}
		if( structKeyExists( err, 'stacktrace' ) ) {
			reader.print( err.stacktrace );
		}
		reader.println();
	}

}
