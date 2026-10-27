import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slipstream/core/service/toast/toast_cubit.dart';
import 'package:slipstream/core/service/toast/toast_message.dart';

void main() {
  test('nothing is shown until show is called', () {
    final cubit = ToastCubit();
    addTearDown(cubit.close);

    expect(cubit.state, isNull);
  });

  test('show publishes the message with its kind and subtitle', () {
    final cubit = ToastCubit();
    addTearDown(cubit.close);

    cubit.show('Config copied', subtitle: 'XRAY JSON', kind: .info);

    final toast = cubit.state!;
    expect(toast.title, 'Config copied');
    expect(toast.subtitle, 'XRAY JSON');
    expect(toast.kind, ToastKind.info);
  });

  test('showSpec shows what the description says', () {
    final cubit = ToastCubit();
    addTearDown(cubit.close);

    cubit.showSpec(
      const ToastSpec('Disconnected', subtitle: 'DIRECT', kind: ToastKind.info),
    );

    final toast = cubit.state!;
    expect(toast.title, 'Disconnected');
    expect(toast.subtitle, 'DIRECT');
    expect(toast.kind, ToastKind.info);
  });

  test('kind defaults to success', () {
    final cubit = ToastCubit();
    addTearDown(cubit.close);

    cubit.show('Done');

    expect(cubit.state!.kind, ToastKind.success);
  });

  test('a toast without a subtitle stays 2.2 s', () {
    fakeAsync((async) {
      final cubit = ToastCubit();
      addTearDown(cubit.close);

      cubit.show('Done');

      async.elapse(const Duration(milliseconds: 2199));
      expect(cubit.state, isNotNull);
      async.elapse(const Duration(milliseconds: 1));
      expect(cubit.state, isNull);
    });
  });

  test('a toast with a subtitle stays 3.2 s', () {
    fakeAsync((async) {
      final cubit = ToastCubit();
      addTearDown(cubit.close);

      cubit.show('Done', subtitle: 'DETAILS');

      async.elapse(const Duration(milliseconds: 3199));
      expect(cubit.state, isNotNull);
      async.elapse(const Duration(milliseconds: 1));
      expect(cubit.state, isNull);
    });
  });

  test('an empty subtitle counts as no subtitle', () {
    fakeAsync((async) {
      final cubit = ToastCubit();
      addTearDown(cubit.close);

      cubit.show('Done', subtitle: '');

      expect(cubit.state!.subtitle, isNull);
      async.elapse(const Duration(milliseconds: 2200));
      expect(cubit.state, isNull);
    });
  });

  test('a new toast replaces the current one with a new id', () {
    final cubit = ToastCubit();
    addTearDown(cubit.close);

    cubit.show('First');
    final firstId = cubit.state!.id;
    cubit.show('Second');

    expect(cubit.state!.title, 'Second');
    expect(cubit.state!.id, isNot(firstId));
  });

  test('the old timer does not close the toast that replaced it', () {
    fakeAsync((async) {
      final cubit = ToastCubit();
      addTearDown(cubit.close);

      cubit.show('First');
      async.elapse(const Duration(milliseconds: 2000));
      cubit.show('Second');

      // 2.2 s after the first toast: its timer would fire here.
      async.elapse(const Duration(milliseconds: 200));
      expect(cubit.state?.title, 'Second');

      // The second one lives its own full 2.2 s.
      async.elapse(const Duration(milliseconds: 2000));
      expect(cubit.state, isNull);
    });
  });

  test('dismiss hides the toast and cancels its timer', () {
    fakeAsync((async) {
      final cubit = ToastCubit();
      addTearDown(cubit.close);

      cubit.show('Done');
      cubit.dismiss();
      expect(cubit.state, isNull);

      expect(async.nonPeriodicTimerCount, 0);
    });
  });

  test('dismiss with nothing shown does nothing', () {
    final cubit = ToastCubit();
    addTearDown(cubit.close);

    cubit.dismiss();

    expect(cubit.state, isNull);
  });

  test('closing the cubit cancels the pending timer', () {
    fakeAsync((async) {
      final cubit = ToastCubit();

      cubit.show('Done');
      cubit.close();

      expect(async.nonPeriodicTimerCount, 0);
    });
  });
}
