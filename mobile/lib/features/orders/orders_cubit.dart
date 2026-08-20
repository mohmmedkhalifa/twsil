import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models.dart';
import '../../core/network/api_client.dart';

class OrdersState {
  final bool loading;
  final List<Order> orders;
  final String? error;
  const OrdersState({
    this.loading = false,
    this.orders = const [],
    this.error,
  });
  OrdersState copyWith({bool? loading, List<Order>? orders, String? error}) =>
      OrdersState(
        loading: loading ?? this.loading,
        orders: orders ?? this.orders,
        error: error ?? this.error,
      );
}

class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit() : super(const OrdersState());

  Future<void> loadMyOrders() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final json = await ApiClient.instance.get('/orders/mine') as List<dynamic>;
      emit(state.copyWith(
        loading: false,
        orders: json.map((o) => Order.fromJson(o as Map<String, dynamic>)).toList(),
      ));
    } catch (e) {
      emit(state.copyWith(loading: false, error: ApiClient.errorMessage(e)));
    }
  }

  Future<void> loadAvailable() async {
    emit(state.copyWith(loading: true, error: null));
    try {
      final json = await ApiClient.instance.get('/orders/available') as List<dynamic>;
      emit(state.copyWith(
        loading: false,
        orders: json.map((o) => Order.fromJson(o as Map<String, dynamic>)).toList(),
      ));
    } catch (e) {
      emit(state.copyWith(loading: false, error: ApiClient.errorMessage(e)));
    }
  }

  void removeOrder(String id) {
    emit(state.copyWith(orders: state.orders.where((o) => o.id != id).toList()));
  }

  void upsertOrder(Order order) {
    final orders = List<Order>.of(state.orders);
    final idx = orders.indexWhere((o) => o.id == order.id);
    if (idx >= 0) {
      orders[idx] = order;
    } else {
      orders.insert(0, order);
    }
    emit(state.copyWith(orders: orders));
  }
}