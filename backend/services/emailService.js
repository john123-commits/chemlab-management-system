const nodemailer = require('nodemailer');

class EmailService {
  constructor() {
    this.transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS
      }
    });
  }

  async sendBorrowingNotification(email, subject, message) {
    const mailOptions = {
      from: process.env.EMAIL_USER,
      to: email,
      subject: subject,
      text: message
    };

    return await this.transporter.sendMail(mailOptions);
  }

  async sendLectureScheduleNotification(email, subject, message) {
    const mailOptions = {
      from: process.env.EMAIL_USER,
      to: email,
      subject: subject,
      text: message
    };

    return await this.transporter.sendMail(mailOptions);
  }
}

module.exports = new EmailService();