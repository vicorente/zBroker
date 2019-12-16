with ZMQ.Sockets; use ZMQ.Sockets;
with ZMQ.Contexts;
with ZMQ.Messages;
--
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with System;
with Ada.Exceptions;
with Ada.Strings.Unbounded.Text_IO;
with System.Address_To_Access_Conversions;
with Ada.Text_IO; use Ada.Text_IO;
with Ada.Containers.Ordered_Maps;

package body Zbroker is

    Ctx         : ZMQ.Contexts.Context;
    Socket      : ZMQ.Sockets.Socket;
    Output_Socket : ZMQ.Sockets.Socket;
    Port : Integer := 5500;
    Output_Port : Integer := 5502;

    Port_Img : constant String := Port'Img;
    Output_Port_Img : constant String := Output_Port'Img;

    -- Endpoint for the publisher
    Publisher_Endpoint : Unbounded_String := To_Unbounded_String("tcp://localhost"  & ":" & Port_Img (2 .. Port_Img'Last));

    -- Endpoint for sending messages
    Output_Endpoint : Sock_Addr_Type := (Family => Family_Inet,
                                        Addr => Addresses (Get_Host_By_Name (Host_Name), 1),
                                        Port => Port_Type(Output_Port));

    package Topics_Containter is new Ada.Containers.Ordered_Maps
      (Element_Type => Unbounded_String,
       Key_Type => Unbounded_String);

    -- Controlled access to the Topics Container
    protected type Protected_Topics_List is
        -- returns True if this Topic is already on the list
        function Contains (Topic : String) return Boolean;
        -- Compares the topic and its associated message in the list
        function Compare (Topic : String; Msg : String) return Boolean;
        -- Sets or replaces the Message related to the topic
        procedure Set (Topic : String; Msg : String);
        -- Removes a Topic from the Topic List
        procedure Delete (Topic : String);
        -- returns the value associated to this topic
        function Get (Topic : String) return String;

    private
        Topic_List : Topics_Containter.Map;
    end Protected_Topics_List;

    protected body Protected_Topics_List is

        function Contains (Topic : String) return Boolean is
        begin
            return Topics_Containter.Contains(Topic_List,To_Unbounded_String(Topic));
        end Contains;

        function Compare (Topic : String; Msg : String) return Boolean is
        begin
            return To_String(Topics_Containter.Element(Topic_List,To_Unbounded_String(Topic))) = Msg;
        end Compare;

        procedure Set (Topic : String; Msg : String) is
        begin
            if Topics_Containter.Contains(Topic_List,To_Unbounded_String(Topic)) then
                Topics_Containter.Replace(Topic_List,
                                          To_Unbounded_String(Topic),
                                          To_Unbounded_String(Msg));
            else
                Topics_Containter.Insert(Topic_List,
                                         To_Unbounded_String(Topic),
                                         To_Unbounded_String(Msg));
            end if;

        end Set;

        procedure Delete (Topic : String) is
        begin
            if Topics_Containter.Contains(Topic_List,To_Unbounded_String(Topic)) then
                Topics_Containter.Delete(Container => Topic_List,
                                         Key       => To_Unbounded_String(Topic));
            end if;
        end Delete;

        function Get (Topic : String) return String is
        begin
            return To_String(Topics_Containter.Element(Topic_List,To_Unbounded_String(Topic)));
        end Get;

    end Protected_Topics_List;

    Topics_List : Protected_Topics_List;

    procedure On_Message_Default(Topic: in String; Payload: in String) is
    begin
        Put_Line ("MQTT: Message received but On_Message callback not defined ");
        Put_Line ("MQTT: Topic:" & Topic & " , Payload:" & Payload);
    end On_Message_Default;

    On_Message : On_Message_Callback := On_Message_Default'Access;


    -----------------------------------------------------------------------
    -- This task listens only Signals and topics this device is
    -- interested in
    -----------------------------------------------------------------------
    task type Listen_Task_Type is
        entry Start;
    end Listen_Task_Type;

    task body Listen_Task_Type is
        Input_Message    : ZMQ.Messages.Message;
    begin

        accept Start;

        loop
            begin
                -- Signals are multipart messages
                -- First part of a message is the signal topic
                -- This way we can subscribe only to the topics we
                -- are interested in
                Input_Message.Initialize(0);
                Put_Line("ESCUCHANDO en " & To_String(Publisher_Endpoint));

                Socket.Recv (Input_Message);
                declare
                    Topic_String : String := To_String(Input_Message.GetData);
                begin
                    -- Receiving the second part of message, message type
                    Input_Message.Initialize(0);
                    Socket.Recv (Input_Message);
                    On_Message (Topic_String, To_String(Input_Message.GetData));
                exception
                    when others =>
                        Put_Line("Exception Subscriber");
                end;
            end;
        end loop;
    end Listen_Task_Type;

    Listen_Task : Listen_Task_Type;

    procedure Connect ( Host: in String; Port: in Integer) is

    begin
        Output_Socket.Initialize(Ctx, ZMQ.Sockets.DEALER);
        Output_Socket.Set_Send_Timeout(Timeout => 0.0);
        Output_Socket.Connect ("tcp://" &  Image(Output_Endpoint));

        Socket.Initialize (Ctx, ZMQ.Sockets.SUB);
        Socket.Connect(Address => Publisher_Endpoint);
        Listen_Task.Start;

    end Connect;


    procedure Subscribe (Topic: in String) is

    begin
        Topics_List.Set(Topic => Topic,
                        Msg   => "");
        Socket.Establish_Message_Filter(Value => Topic);
    end Subscribe;

    procedure Unsubscribe (Topic: in String) is

    begin
        Topics_List.Delete(Topic => Topic);
        Socket.Remove_Message_Filter(Value => Topic);
    end Unsubscribe;

    procedure Publish (Topic, Msg: in String) is
        Output_Message :  ZMQ.Messages.Message;

    begin
        Output_Socket.Send(Topic, ZMQ.Sockets.Send_More);
        -- Second part is message type
        Output_Socket.Send(Msg, 0);
        Put_Line("Sending...");
    end Publish;

    function Get_Value (Topic: String) return String is
    begin
        if Topics_List.Contains(Topic => Topic) then
            return Topics_List.Get(Topic => Topic);
        else
            Put_Line("ERROR:: not subscribed to signal: " & Topic);
            return "";
        end if;
    end Get_Value;

    procedure Disconnect is
    begin
        Socket.Finalize;
    end Disconnect;


    procedure Set_On_Message (Handler: in On_Message_Callback) is
    begin
        On_Message := Handler;
    end Set_On_Message;
end Zbroker;
