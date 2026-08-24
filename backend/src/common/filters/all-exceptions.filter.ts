import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { QueryFailedError } from 'typeorm';

/**
 * Turns every unhandled failure into a JSON body the clients can show,
 * with a human-readable message instead of a bare
 * "Internal Server Error". Full stack traces stay in the server logs.
 */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse();
    const req = ctx.getRequest();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message = 'حدث خطأ غير متوقع في الخادم، حاول مرة أخرى';
    let error = 'Internal Server Error';

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const body: any = exception.getResponse();
      message =
        typeof body === 'string'
          ? body
          : Array.isArray(body?.message)
            ? body.message.join(', ')
            : body?.message ?? exception.message;
      error = body?.error ?? HttpStatus[status] ?? error;
    } else if (exception instanceof QueryFailedError) {
      const pgCode = (exception as any).code as string | undefined;
      ({ status, message, error } = this.mapDbError(pgCode, exception.message));
    } else if (exception instanceof Error) {
      message = 'حدث خطأ غير متوقع في الخادم، حاول مرة أخرى';
    }

    if (status >= 500) {
      this.logger.error(
        `${req.method} ${req.originalUrl} -> ${status}: ${
          exception instanceof Error ? exception.stack : String(exception)
        }`,
      );
    }

    res.status(status).json({
      statusCode: status,
      message,
      error,
      path: req.originalUrl,
      timestamp: new Date().toISOString(),
    });
  }

  private mapDbError(code: string | undefined, raw: string) {
    if (code === '22P02' || /invalid input value for enum/i.test(raw)) {
      return { status: HttpStatus.BAD_REQUEST, message: 'قيمة غير صالحة لأحد الحقول (تحقق من طريقة الدفع أو الحالة المرسلة)', error: 'Bad Request' };
    }
    if (code === '23505' || /duplicate key/i.test(raw)) {
      return { status: HttpStatus.CONFLICT, message: 'هذا السجل موجود بالفعل', error: 'Conflict' };
    }
    if (code === '23503' || /violates foreign key/i.test(raw)) {
      return { status: HttpStatus.BAD_REQUEST, message: 'لا يمكن تنفيذ العملية لارتباط السجل ببيانات أخرى', error: 'Bad Request' };
    }
    if (code === '42703' || /column .* does not exist/i.test(raw)) {
      return { status: HttpStatus.INTERNAL_SERVER_ERROR, message: 'خطأ في مخطط قاعدة البيانات: عمود مفقود. يرجى تشغيل أحدث ترحيل (migration).', error: 'Internal Server Error' };
    }
    if (/relation .* does not exist/i.test(raw)) {
      return { status: HttpStatus.INTERNAL_SERVER_ERROR, message: 'خطأ في مخطط قاعدة البيانات: جدول مفقود. يرجى تشغيل أحدث ترحيل (migration).', error: 'Internal Server Error' };
    }
    return { status: HttpStatus.INTERNAL_SERVER_ERROR, message: 'تعذر إتمام عملية قاعدة البيانات، حاول مرة أخرى', error: 'Internal Server Error' };
  }
}
