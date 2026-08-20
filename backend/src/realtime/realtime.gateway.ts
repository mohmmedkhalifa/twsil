import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { UseGuards } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

export interface TrackingPayload {
  orderId: string;
  lat: number;
  lng: number;
}

interface SocketWithUser extends Socket {
  userId?: string;
  role?: string;
}

@WebSocketGateway({
  cors: { origin: '*' },
  namespace: '/',
})
export class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private readonly onlineUsers = new Map<string, Set<string>>();

  constructor(private readonly jwtService: JwtService) {}

  async handleConnection(client: SocketWithUser) {
    const token = client.handshake.auth?.token as string | undefined;
    if (!token) {
      client.disconnect(true);
      return;
    }
    try {
      const payload = await this.jwtService.verifyAsync(token);
      client.userId = payload.sub;
      client.role = payload.role;
      await client.join(`user:${payload.sub}`);
      if (payload.role === 'captain') await client.join('captains-room');
      if (payload.role === 'customer') await client.join('customers-room');
      this.addOnline(payload.sub, client.id);
    } catch {
      client.disconnect(true);
    }
  }

  handleDisconnect(client: SocketWithUser) {
    if (client.userId) this.removeOnline(client.userId, client.id);
  }

  private addOnline(userId: string, socketId: string) {
    const set = this.onlineUsers.get(userId) ?? new Set<string>();
    set.add(socketId);
    this.onlineUsers.set(userId, set);
  }

  private removeOnline(userId: string, socketId: string) {
    const set = this.onlineUsers.get(userId);
    if (!set) return;
    set.delete(socketId);
    if (set.size === 0) this.onlineUsers.delete(userId);
  }

  isUserOnline(userId: string): boolean {
    return this.onlineUsers.has(userId);
  }

  async joinOrder(socket: Socket, orderId: string) {
    await socket.join(`order:${orderId}`);
  }

  sendToUser(userId: string, event: string, payload: unknown) {
    this.server.to(`user:${userId}`).emit(event, payload);
  }

  sendToOrder(orderId: string, event: string, payload: unknown) {
    this.server.to(`order:${orderId}`).emit(event, payload);
  }

  sendToCaptains(event: string, payload: unknown) {
    this.server.to('captains-room').emit(event, payload);
  }

  sendToCustomers(event: string, payload: unknown) {
    this.server.to('customers-room').emit(event, payload);
  }

  broadcast(event: string, payload: unknown) {
    this.server.emit(event, payload);
  }

  @SubscribeMessage('tracking:update')
  handleTracking(
    @ConnectedSocket() client: SocketWithUser,
    @MessageBody() body: TrackingPayload,
  ) {
    if (client.role !== 'captain') return;
    if (!body?.orderId || typeof body.lat !== 'number' || typeof body.lng !== 'number') return;
    client.to(`order:${body.orderId}`).emit('tracking:update', {
      orderId: body.orderId,
      lat: body.lat,
      lng: body.lng,
      at: new Date().toISOString(),
    });
  }

  @SubscribeMessage('order:join')
  handleOrderJoin(
    @ConnectedSocket() client: SocketWithUser,
    @MessageBody() body: { orderId: string },
  ) {
    if (!body?.orderId) return;
    void this.joinOrder(client, body.orderId);
  }

  @SubscribeMessage('chat:join')
  handleChatJoin(
    @ConnectedSocket() client: SocketWithUser,
    @MessageBody() body: { conversationId: string },
  ) {
    if (!body?.conversationId) return;
    void client.join(`conversation:${body.conversationId}`);
  }

  @SubscribeMessage('chat:typing')
  handleTyping(
    @ConnectedSocket() client: SocketWithUser,
    @MessageBody() body: { conversationId: string; typing: boolean },
  ) {
    if (!body?.conversationId) return;
    client.to(`conversation:${body.conversationId}`).emit('chat:typing', {
      conversationId: body.conversationId,
      userId: client.userId,
      typing: body.typing,
    });
  }

  sendToConversation(conversationId: string, event: string, payload: unknown) {
    this.server.to(`conversation:${conversationId}`).emit(event, payload);
  }
}