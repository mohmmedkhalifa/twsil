import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Complaint, ComplaintStatus } from '../database/entities/complaint.entity';
import { User, UserRole } from '../database/entities/user.entity';
import { NotificationsService } from '../notifications/notifications.service';

export class CreateComplaintDto {
  againstUserId?: string;
  orderId?: string;
  subject: string;
  description: string;
}

export class UpdateComplaintDto {
  status?: ComplaintStatus;
  resolutionNote?: string;
  action?: string;
  adminNote?: string;
}

@Injectable()
export class ComplaintsService {
  constructor(
    @InjectRepository(Complaint)
    private readonly complaintsRepo: Repository<Complaint>,
    @InjectRepository(User)
    private readonly usersRepo: Repository<User>,
    private readonly notifications: NotificationsService,
  ) {}

  async create(reporterId: string, dto: CreateComplaintDto) {
    if (!dto.subject || !dto.description) {
      throw new NotFoundException('Subject and description are required');
    }
    const complaint = await this.complaintsRepo.save(
      this.complaintsRepo.create({ reporterId, ...dto }),
    );
    const admins = await this.usersRepo.find({ where: { role: UserRole.Admin } });
    await this.notifications.push(
      admins.map((a) => a.id),
      'complaint:new',
      'شكوى جديدة',
      `شكوى: ${dto.subject}`,
      { complaintId: complaint.id },
    );
    await this.notifications.push(
      [reporterId],
      'complaint:submitted',
      'تم استلام الشكوى',
      'تم تسجيل شكواك وسيقوم فريق الدعم بمراجعتها.',
      { complaintId: complaint.id },
    );
    return complaint;
  }

  listAll(status?: ComplaintStatus) {
    const qb = this.complaintsRepo
      .createQueryBuilder('c')
      .leftJoinAndSelect('c.reporter', 'reporter')
      .leftJoinAndSelect('c.againstUser', 'against')
      .leftJoinAndSelect('c.order', 'order')
      .orderBy('c.createdAt', 'DESC');
    if (status) qb.where('c.status = :status', { status });
    return qb.getMany();
  }

  listMine(userId: string) {
    return this.complaintsRepo.find({
      where: { reporterId: userId },
      order: { createdAt: 'DESC' },
    });
  }

  async update(id: string, adminId: string, dto: UpdateComplaintDto) {
    const complaint = await this.complaintsRepo.findOne({ where: { id } });
    if (!complaint) throw new NotFoundException('Complaint not found');
    const resolved = dto.action === 'resolve' || dto.status === ComplaintStatus.Resolved;
    const note = dto.adminNote ?? dto.resolutionNote;
    Object.assign(complaint, {
      ...(dto.status ? { status: dto.status } : {}),
      ...(resolved ? { status: ComplaintStatus.Resolved } : {}),
      ...(note !== undefined ? { resolutionNote: note } : {}),
    });
    if (resolved) {
      complaint.resolvedById = adminId;
      complaint.resolvedAt = new Date();
    }
    await this.complaintsRepo.save(complaint);
    await this.notifications.push(
      [complaint.reporterId],
      'complaint:updated',
      'تحديث على شكواك',
      note ?? (resolved ? 'تم حل شكواك' : `تم تحديث حالة الشكوى إلى ${dto.status}`),
      { complaintId: complaint.id },
    );
    return complaint;
  }
}