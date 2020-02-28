------------------------------------------------------------------------------
--
-- This package provides a simple interprogram message communication facility
-- using ZER0MQ library.
--
-- It uses a PUB/SUB pattern
------------------------------------------------------------------------------
with ZMQ;
with ZMQ.Sockets;
--
with GNAT.Sockets; use GNAT.Sockets;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;


package Zbroker is

    -- We can embed any Message inside a Signal
    type Signal_Message_Type is
        record
           -- Message type contained in Signal
           Topic : Unbounded_String;
           Data : Unbounded_String;
       end record;

   type On_Message_Callback is access procedure (Topic: in String; Payload: in String);

    -- Function: Connect
    -- This function connects to broker.
    -- Parameters:
    --    - Host: the hostname or ip address of the broker to connect to.
    --    - Broker_Pub_Port: the network port to subscribe to
    --    - Broker_Input_Port: the network port to send messages to
    --
    procedure Connect ( Host: in String; Broker_Pub_Port: in Integer; Broker_Input_Port: in Integer);

    -- Function: Unsubscribe
    -- Subscribe to topic.
    -- Parameters:
    --    - Topic: topic to unsusbcribe to of String type.
    --
    procedure Unsubscribe (Topic: in String);

    -- Function: Unsubscribe_All
    -- Unsubscribe to all topics.
    procedure Unsubscribe_All;

    -- Function: Subscribe
    -- Subscribe to topic.
    -- Parameters:
    --    - Topic: topic to susbcribe to of String type.
    --
    procedure Subscribe (Topic: in String);

    -- Function: Publish
    -- Publish a message with a topic.
    -- Parameters:
    --    - Topic: topic to publish to.
    --    - Msg: message to publish.
    --
    procedure Publish (Topic, Msg: in String);

    -- Function: Get_Value
    -- Get the value of a topic.
    -- Parameters:
    --    - Topic: topic of the value to be got.
    --
    function Get_Value(Topic: String) return  String;

    -- Function: Disconnect
    -- This function disconnects of broker.
    -- Parameters: NONE
    --
    procedure Disconnect;

    -- Function: Set_On_Message
    -- Set new procedure for on-message callback. If not called when subscribe, a predefined
    -- function will be used.
    -- Parameters:
    --      - Handler: Access to new On_Message procedure.
    --                 New function must have two input parameters of type String: Topic and Payload.
    --
    procedure Set_On_Message (Handler: in On_Message_Callback);


end Zbroker;
