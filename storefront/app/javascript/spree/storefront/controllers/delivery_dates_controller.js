import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = { start: Number, end: Number }

  connect() {
    this.element.innerHTML = this.totalDaysWithWeekends(this.startValue, this.endValue);
  }

  totalDaysWithWeekends(startAt, endAt) {
    const startDate = new Date();
    const endDate = endAt ? new Date() : null;

    this.calculateDate(startDate, startAt);

    if (endDate)
      this.calculateDate(endDate, endAt);

    const startDateFormat = this.formatDate(startDate)

    if (endDate && startDate.getTime() !== endDate.getTime()) {
      const endDateFormat = this.formatDate(endDate)
      return `${startDateFormat} - ${endDateFormat}`;
    } else {
      return startDateFormat
    }
  }

  calculateDate(date, daysToAdd) {
    let addedDays = 0;
    while (addedDays < daysToAdd) {
      date.setDate(date.getDate() + 1);

      if (date.getDay() !== 0 && date.getDay() !== 6) {
        addedDays++;
      }
    }
  }

  formatDate(date) {
    const day = date.getDate()
    const dayOrdinal = this.getDayOrdinal(day)
    const month = date.toLocaleString('default', { month: 'long' })

    return `${day}${dayOrdinal} ${month}`;
  }

  getDayOrdinal(day) {
    if (day > 3 && day < 21) return 'th';

    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}
