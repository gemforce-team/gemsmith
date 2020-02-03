package Gemsmith 
{
	/**
	 * ...
	 * @author Hellrage
	 */
	
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.globalization.DateTimeFormatter;
	
	public class Logger 
	{
		private static var logFile:File;
		private static var logStream:FileStream;
		
		public static function init(): void
		{
			logFile = File.applicationStorageDirectory.resolvePath("Gemsmith/Gemsmith_log.log");
			if(logFile.exists)
				logFile.deleteFile();
			logStream = new FileStream();
		}
		
		// UglyLog is ugly because I open, write, close the stream every time this method is called
		// This is to guarantee that the messages arrive at the log in case of an uncaught exception
		public static function UglyLog(source:String, message:String): void
		{
			logStream.open(logFile, FileMode.APPEND);
			var df:DateTimeFormatter = new DateTimeFormatter("");
			df.setDateTimePattern("yyyy-MM-dd HH:mm:ss");
			logStream.writeUTFBytes(df.format(new Date()) + "\t[" + source.substring(0,10) + "]:\t" + message + "\r\n");
			logStream.close();
		}
	}

}