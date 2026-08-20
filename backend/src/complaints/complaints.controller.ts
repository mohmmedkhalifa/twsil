import { Body, Controller, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { UserRole } from '../database/entities/user.entity';
import { ComplaintStatus } from '../database/entities/complaint.entity';
import { ComplaintsService, CreateComplaintDto, UpdateComplaintDto } from './complaints.service';

@Controller('complaints')
@UseGuards(JwtAuthGuard, RolesGuard)
export class ComplaintsController {
  constructor(private readonly complaints: ComplaintsService) {}

  @Post()
  create(@CurrentUser() user: { id: string }, @Body() dto: CreateComplaintDto) {
    return this.complaints.create(user.id, dto);
  }

  @Get('mine')
  mine(@CurrentUser() user: { id: string }) {
    return this.complaints.listMine(user.id);
  }

  @Get('admin/list')
  @Roles(UserRole.Admin)
  list(@Query('status') status?: string) {
    return this.complaints.listAll(status as ComplaintStatus | undefined);
  }

  @Patch('admin/:id')
  @Roles(UserRole.Admin)
  update(@Param('id') id: string, @CurrentUser() user: { id: string }, @Body() dto: UpdateComplaintDto) {
    return this.complaints.update(id, user.id, dto);
  }
}