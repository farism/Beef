using System.IO;
using System.Collections;
using System.Text;
using System.Threading;

namespace System
{
	public static class Environment
	{
#if BF_PLATFORM_WINDOWS
		public const String NewLine = "\r\n";
#else
		public const String NewLine = "\n";
#endif // BF_PLATFORM_WINDOWS


		static OperatingSystem sOSVersion ~ delete _;
		public static OperatingSystem OSVersion
		{
			get
			{
				if (sOSVersion == null)
				{
					var osVersion = new OperatingSystem();
					if (let prevValue = Interlocked.CompareExchange(ref sOSVersion, null, osVersion))
					{
						// This was already set - race condition
						delete osVersion;
						return prevValue;
					}
				}
				return sOSVersion;
			}
		}

		public static void* ModuleHandle => Internal.[Friend]sModuleHandle;

#if BF_PLATFORM_WINDOWS
		public const bool IsFileSystemCaseSensitive = false;
#else
		public const bool IsFileSystemCaseSensitive = true;
#endif

		static String GetResourceString(String key)
		{
			return key;
            //return GetResourceFromDefault(key);
		}

		static String GetResourceString(String key, params Object[] values)
		{
			return key;
            //return GetResourceFromDefault(key);
		}

		static String GetRuntimeResourceString(String key, String defaultValue = null)
		{
			if (defaultValue != null)
				return defaultValue;
			return key;
            //return GetResourceFromDefault(key);
		}

		public static void GetExecutableFilePath(String outPath)
		{
			Platform.GetStrHelper(outPath, scope (outPtr, outSize, outResult) =>
                {
					Platform.BfpSystem_GetExecutablePath(outPtr, outSize, (Platform.BfpSystemResult*)outResult);
                });
		}

		public static void GetModuleFilePath(String outPath)
		{
			Platform.GetStrHelper(outPath, scope (outPtr, outSize, outResult) =>
		        {
					Platform.BfpDynLib_GetFilePath((.)Internal.[Friend]sModuleHandle, outPtr, outSize, (Platform.BfpLibResult*)outResult);
		        });
		}

		public static uint32 TickCount
		{
			get
			{
				return Platform.BfpSystem_TickCount();
			}
		}

		public static void GetEnvironmentVariables(Dictionary<String, String> envVars)
		{
			String envStr = scope String();
			Platform.GetStrHelper(envStr, scope (outPtr, outSize, outResult) =>
				{
					Platform.BfpSystem_GetEnvironmentStrings(outPtr, outSize, (Platform.BfpSystemResult*)outResult);
				});

			readonly char8* cPtrHead = envStr;
			char8* cPtr = cPtrHead;
			char8* cPtrEntry = cPtr;

			while (true)
			{
				char16 c = *(cPtr++);
				if (c == 0)
				{
					let str = scope String(cPtrEntry);

					int eqPos = str.IndexOf('=', 1);
					if (eqPos != -1)
					{
						let key = new String(str, 0, eqPos);
						let value = new String(str, eqPos + 1);
						envVars[key] = value;
					}

					cPtrEntry = cPtr;
					if (*cPtrEntry == 0)
						break;
				}

			}
		}

		public static void SetEnvironmentVariable(Dictionary<String, String> envVars, StringView key, StringView value)
		{
			let newKey = new String(key);
			switch (envVars.TryAdd(newKey))
			{
			case .Added(let keyPtr, let valuePtr):
				*valuePtr = new String(value);
			case .Exists(let keyPtr, let valuePtr):
				delete newKey;
				(*valuePtr).Set(value);
			}
		}

		public static void EncodeEnvironmentVariablesW(Dictionary<String, String> envVars, List<uint8> data)
		{
			var keys = scope String[envVars.Count];
			var values = scope String[envVars.Count];
			int idx = 0;
			for (let kv in envVars)
			{
				keys[idx] = kv.key;
				values[idx] = kv.value;
				++idx;
			}

			//TODO: This is really supposed to be a UTF16-ordinal compare
			Array.Sort(keys, values, scope (lhs, rhs) => { return String.Compare(lhs, rhs, true); } );

			for (var key in keys)
			{
				int allocSize = UTF16.GetEncodedLen(key);
				char16* encodedData = scope char16[allocSize]*;
				int encodedLen = UTF16.Encode(key, encodedData, allocSize);
				int byteLen = encodedLen * 2;
				Internal.MemCpy(data.GrowUninitialized(byteLen), encodedData, byteLen);

				data.Add((uint8)'='); data.Add((uint8)0);

				let value = values[@key];
				allocSize = UTF16.GetEncodedLen(value);
				encodedData = scope char16[allocSize]*;
				encodedLen = UTF16.Encode(value, encodedData, allocSize);
				byteLen = encodedLen * 2;
				Internal.MemCpy(data.GrowUninitialized(byteLen), encodedData, byteLen);

				data.Add(0); data.Add(0); // Single UTF16 char
			}

			data.Add(0); data.Add(0); // Single UTF16 char
		}

		public static void EncodeEnvironmentVariables(Dictionary<String, String> envVars, List<char8> data)
		{
			var keys = scope String[envVars.Count];
			var values = scope String[envVars.Count];
			int idx = 0;
			for (let kv in envVars)
			{
				keys[idx] = kv.key;
				values[idx] = kv.value;
				++idx;
			}

			//TODO: This is really supposed to be a UTF16-ordinal compare
			Array.Sort(keys, values, scope (lhs, rhs) => { return String.Compare(lhs, rhs, true); } );

			for (var key in keys)
			{
				int byteLen = key.Length;
				Internal.MemCpy(data.GrowUninitialized(byteLen), key.Ptr, byteLen);

				data.Add('=');

				let value = values[@key];
				byteLen = value.Length;
				Internal.MemCpy(data.GrowUninitialized(byteLen), value.Ptr, byteLen);

				data.Add(0);
			}

			data.Add(0);
		}

		[LinkName("exit")]
		public static extern void Exit(int exitCode);
	}
}
