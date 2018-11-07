Netty-Socketio主要类和方法如下：  

SocketIOClient: 客户端接口，其实现类是NamespaceClient，
主要方法如下：  
    joinRoom() 加入到指定房间。  
    leaveRoom() 从指定房间离开。  
    getSessionId()方法，返回由UUID生成的唯一标识。  
    getAllRooms() 返回当前客户端所在的room名称列表。  
    sendEvent(eventname,data) 向当前客户端发送事件。  
 
SocketIOServer:   服务端实例，对应node版的Server对象，
主要方法如下：  
    getAllClients() 返回默认名称空间中的所有客户端实例。  
    getBroadcastOperations() 返回默认名称空间的所有实例组成的广播对象。  
    getRoomOperations() 返回所有命名空间中指定房间的广播对象，如果命名空间只有一个，该方法到可以大胆使用。  
    getClient(uid) 返回默认名称空间的指定客户端。  
    getNamespace() 返回指定名称的命名空间。  

Namespace: 命名空间。与node版的namespace一模一样，作为socketio的java实现版，netty-socketio忠实的重现了socketio的server–>namespace–room三层嵌套关系。 
SocketIOServer通过NamespacesHub对象持有namespace的对象列表，借助NamespacesHub的CRUD方法，SocketIOServer实现了对namespace的管理。 
从NamespacesHub的getRoomClients方法可以知道，SocketIOServer的getRoomOperations方法返回的是所有namespace中指定room中的客户端实例。而不是指定命名空间或者默认命名空间的，使用该方法的时候要小心。如果要获取指定命名空间的指定room中的客户端，一定要先拿到指定namespace对象。 
Namespace中的主要方法如下：  
    getAllClients() 获得本namespace中的所有客户端。  
    getClient() 获得指定id客户端对象。  
    getRoomClients(room) 获得本空间中指定房间中的客户端。  
    getRooms() 获得本空间中的所有房间。  
    getRooms(client) 获得指定客户端所在的房间列表。  
    leave(room,uuid) 将指定客户端离开指定房间，如果房间中已无客户端，删除该房间。   
    getBroadcastOperations 返回针对空间中所有客户端的广播对象。   
    getRoomOperations(room) 返回针对指定房间的广播对象。   

BroadcastOperations :广播操作对象，通过对Namespace的了解我们知道，BroadcastOperations都是命名空间以指定room中的clients列表为参数创建的。 
BroadcastOperations中最通用的方法便是sendEvent方法，该方法遍历clients，通过执行客户端的send方法实现广播目的。也可以设定一个排除对象，当然用于排除发送者自己了。
  主要方法如下：  
  sendEvent(eventname,data) 向本广播对象中的全体客户端发送广播。 
  sendEvent(eventname,excludeSocketIOClient,data) 排除指定客户端广播。  

AckRequest: 是一个为了实现socketio中客户端emit函数的第三个参数而定义的类。 

ack是一个客户端的一个回调函数，客户端触发的事件如果被服务端收到，服务端可以触发该函数的执行。   
SocketIOServer的事件监听方法第三个参数便是对应的AckRequest对象，可以使用sendAckData方法设置回调参数。    
public void onData(final SocketIOClient client, ChatObject data, final AckRequest ackRequest) {  
   
  if (ackRequest.isAckRequested()) {   
      ackRequest.sendAckData(“client message was delivered to server!”, “yeah!”);   
  } 
} 

AckCallback   
同样的，既然服务端可以执行客户端的回调函数，那客户端也可以做同样的事情。AckCallback和VoidAckCallback便是netty-socketio模拟的服务端回调函数。  
