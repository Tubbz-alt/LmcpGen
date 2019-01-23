-<include_all_series_headers>-
with Ada.Unchecked_Conversion;
with GNAT.Byte_Swapping;

package body -<full_series_name_dots>-.factory is

   function packMessage(rootObject : in avtas.lmcp.object.Object_Any; enableChecksum : in Boolean) return ByteBuffer is
      msgSize : UInt32_t;
   begin
      -- Allocate space for message, with 15 extra bytes for
      --  Existence (1 byte), series name (8 bytes), type (4 bytes), version number (2 bytes)
      msgSize := rootObject.calculatePackedSize + 15;
      declare
         buffer : ByteBuffer(HEADER_SIZE + msgSize + CHECKSUM_SIZE);
      begin
         -- add header values
         Put_Int32(buffer, LMCP_CONTROL_STR);
         Put_UInt32(buffer, msgSize);

         -- If root object is null, pack a 0; otherwise, add root object
         if(rootObject = null) then
            Put_Boolean(buffer, False);
         else
            Put_Boolean(buffer, True);
            Put_Int64(buffer, rootObject.getSeriesNameAsLong);
            Put_UInt32(buffer, rootObject.getLmcpType);
            Put_UInt16(buffer, rootObject.getSeriesVersion);
            pack(rootObject, buffer);
         end if;

         -- add checksum if enabled
         Put_UInt32(buffer, (if enableChecksum then calculateChecksum(buffer) else 0));
         return buffer;
      end;
   end packMessage;

   procedure getObject(buffer : in out ByteBuffer; output : out avtas.lmcp.object.Object_Any) is
      ctrlStr : Int32_t;
      msgSize : UInt32_t;
      msgExists : Boolean;
      seriesId : Int64_t;
      msgType : Uint32_t;
      version : Uint16_t;
   begin
      -- TODO: add some kind of warning/error messages for each null case
      if buffer.Capacity < HEADER_SIZE + CHECKSUM_SIZE then
         output := null;
      else
         Get_Int32(buffer, ctrlStr);
         if ctrlStr /= LMCP_CONTROL_STR then
            output := null;
         else
            Get_UInt32(buffer, msgSize);
            if buffer.Capacity < msgSize then
               output := null;
            elsif(validate(buffer) = False) then
               output := null;
            else
               Get_Boolean(buffer, msgExists);
               if(msgExists = False) then
                  output := null;
               else
                  Get_Int64(buffer, seriesId);
                  Get_UInt32(buffer, msgType);
                  Get_UInt16(buffer, version);
                  output := createObject(seriesId, msgType, version);
                  if (output /= null) then
                     unpack(output, buffer);
                  end if;
               end if;
            end if;
         end if;
      end if;
   end getObject;

   function createObject(seriesId : in Int64_t; msgType : in UInt32_t; version: in UInt16_t) return avtas.lmcp.object.Object_Any is
   begin
      -<series_factory_switch>-
   end createObject;

   function calculateChecksum (buffer : in ByteBuffer) return UInt32_t is
      sum : UInt32_t := 0;
      subtype ByteArray32 is ByteArray(1 .. 32);
      function IntToByteArray is new Ada.Unchecked_Conversion(Source => UInt32_t, Target => ByteArray32);
      function ByteArrayToInt is new Ada.Unchecked_Conversion(Source => ByteArray32, Target => UInt32_t);
   begin
      for i in 1 .. buffer.Capacity - CHECKSUM_SIZE loop
         sum := sum + UInt32_t(buffer.Buf(i));
      end loop;
      -- The C++ code does the following, but why? It seems like a no-op to me
      -- Can't we just return sum?
      return (ByteArrayToInt(IntToByteArray(sum) & IntToByteArray(UInt32_t(16#FFFFFFFF#))));
   end calculateChecksum;

   function getObjectSize (buffer : in ByteBuffer) return UInt32_t is
      function ByteArrayToInt is new Ada.Unchecked_Conversion(Source => ByteArray4, Target => UInt32_t);
   begin
      return ByteArrayToInt(buffer.Buf(5 .. 8));
   end getObjectSize;

   function validate(buffer : in ByteBuffer) return Boolean is
      subtype ByteArray32 is ByteArray(1 .. 32);
      function ByteArrayToInt is new Ada.Unchecked_Conversion(Source => ByteArray32, Target => UInt32_t);
      subtype SwapType is ByteArray4;
      function SwapBytes is new GNAT.Byte_Swapping.Swapped4 (swapType);
      sum : UInt32_t;
   begin
      sum := calculateChecksum(buffer);
      return sum = 0 or else sum = ByteArrayToInt(SwapBytes(buffer.Buf(buffer.Buf'Last - 3 .. buffer.Buf'Last)));
   end validate;

end -<full_series_name_dots>-.factory;